import os
import sys
import argparse
from datetime import datetime
import matplotlib
matplotlib.rc('font', family='NanumGothic')
import matplotlib.pyplot as plt
plt.rcParams['axes.unicode_minus'] = False
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, explode, desc, to_date
from matplotlib.backends.backend_pdf import PdfPages
from hdfs import InsecureClient
import numpy as np
import pandas as pd
import textwrap

from wordcloud import WordCloud
from konlpy.tag import Okt
from transformers import pipeline

from pyspark.ml.feature import PCA as SparkPCA
from pyspark.ml.clustering import KMeans as SparkKMeans
from pyspark.ml.linalg import Vectors, VectorUDT
from pyspark.sql.functions import udf

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    return parser.parse_args()

def extract_nouns(texts):
    okt = Okt()
    nouns = []
    for t in texts:
        nouns += okt.nouns(t)
    return nouns

def to_vector_udt(array):
    return Vectors.dense(array)

to_vector_udt_udf = udf(to_vector_udt, VectorUDT())

def main(report_date_str):
    HDFS_HOSTPORT = "hdfs://hadoop-namenode:9000"
    WEBHDFS_URL = "http://hadoop-namenode:9870"
    REALTIME_DIR = "/batch/data/realtime"
    ARCHIVE_DIR = "/batch/data/news_archive"
    HDFS_PDF_DIR = "/batch/data/pdf"
    LOCAL_PDF_DIR = "/tmp"
    INPUT_PATH = f"{HDFS_HOSTPORT}{REALTIME_DIR}/*.json"
    os.makedirs(LOCAL_PDF_DIR, exist_ok=True)

    spark = SparkSession.builder.appName("DailyNewsReport").getOrCreate()
    try:
        df = spark.read.option("multiline", "true").json(INPUT_PATH)
    except Exception as e:
        print(f"데이터 읽기 실패: {e}")
        spark.stop()
        sys.exit(1)

    report_date = datetime.strptime(report_date_str, "%Y-%m-%d").date()
    df = df.withColumn("published_date", to_date(col("published_at")))
    daily_df = df.filter(col("published_date") == report_date_str)
    summary = {}

    if daily_df.count() > 0:
        # 카테고리별 기사 수
        category_count = (
            daily_df.groupBy("category").count().orderBy(desc("count")).toPandas()
        )
        # 키워드별 빈도
        keywords_exploded = daily_df.withColumn("keyword", explode(col("keywords")))
        keyword_count = (
            keywords_exploded.groupBy("keyword").count().orderBy(desc("count")).toPandas()
        )
        # 기사 목록 - keywords 컬럼 반드시 포함
        articles = daily_df.select(
            "id", "title", "content", "category", "published_at", "embedding", "keywords"
        ).toPandas()

        # embedding 관련
        embedding_filtered_df = daily_df.dropna(subset=["embedding"])
        if embedding_filtered_df.count() > 1:
            # Spark VectorUDT로 변환
            embedding_df = embedding_filtered_df.withColumn("embedding_vec", to_vector_udt_udf(col("embedding")))
            # PCA (Spark MLlib)
            pca = SparkPCA(k=2, inputCol="embedding_vec", outputCol="pca_features")
            pca_model = pca.fit(embedding_df)
            embedding_df = pca_model.transform(embedding_df)
            # KMeans (Spark MLlib) - 군집 개수 5개로 고정
            n_clusters = min(5, embedding_df.count())
            kmeans = SparkKMeans(k=n_clusters, seed=42, featuresCol="embedding_vec", predictionCol="cluster")
            kmeans_model = kmeans.fit(embedding_df)
            embedding_df = kmeans_model.transform(embedding_df)
            # Pandas 변환 (시각화용)
            embedding_pd = embedding_df.select("title", "pca_features", "cluster").toPandas()
            embedding_pd["pc1"] = embedding_pd["pca_features"].apply(lambda v: float(v[0]))
            embedding_pd["pc2"] = embedding_pd["pca_features"].apply(lambda v: float(v[1]))
        else:
            embedding_pd = None
            n_clusters = 0
        summary["category_count"] = category_count
        summary["keyword_count"] = keyword_count
        summary["articles"] = articles
        summary["embedding_pd"] = embedding_pd
        summary["n_clusters"] = n_clusters
    else:
        summary["category_count"] = None
        summary["keyword_count"] = None
        summary["articles"] = None
        summary["embedding_pd"] = None
        summary["n_clusters"] = 0

    # 워드클라우드용 전체 content 추출
    all_contents = summary["articles"]["content"].tolist() if summary["articles"] is not None else []
    all_keywords = []
    if summary["articles"] is not None and "keywords" in summary["articles"].columns:
        all_keywords = sum(summary["articles"]["keywords"].tolist(), [])

    # 감성분석 준비
    try:
        sentiment_analyzer = pipeline("sentiment-analysis", model="snunlp/KR-FinBert-SC", tokenizer="snunlp/KR-FinBert-SC")
    except Exception as e:
        sentiment_analyzer = None
        print(f"감성분석 모델 로딩 실패: {e}")

    # PDF 리포트 생성
    pdf_filename = f"daily_report_{report_date_str}.pdf"
    pdf_local_path = os.path.join(LOCAL_PDF_DIR, pdf_filename)
    with PdfPages(pdf_local_path) as pdf:
        # 카테고리별 기사 수 - 각 카테고리별로 색 다르게
        plt.figure(figsize=(8, 4))
        plt.title(f"뉴스 카테고리별 기사 수 ({report_date_str})", fontsize=16, fontweight='bold')
        if summary["category_count"] is not None and not summary["category_count"].empty:
            categories = summary["category_count"]["category"]
            counts = summary["category_count"]["count"]
            colors = plt.cm.tab10.colors
            color_list = [colors[i % len(colors)] for i in range(len(categories))]
            plt.bar(categories, counts, color=color_list)
            plt.xlabel("카테고리")
            plt.ylabel("기사 수")
            plt.tight_layout()
        else:
            plt.text(0.5, 0.5, "해당 날짜에 대한 데이터가 없습니다.", ha='center', va='center', fontsize=14)
        plt.tight_layout()
        pdf.savefig()
        plt.close()

        # 키워드별 빈도수 - 각 키워드별로 색 다르게
        plt.figure(figsize=(8, 4))
        plt.title(f"키워드별 빈도수 Top 10 ({report_date_str})", fontsize=16, fontweight='bold')
        if summary["keyword_count"] is not None and not summary["keyword_count"].empty:
            top_keywords = summary["keyword_count"].head(10)
            keywords = top_keywords["keyword"]
            counts = top_keywords["count"]
            colors = plt.cm.Paired.colors
            color_list = [colors[i % len(colors)] for i in range(len(keywords))]
            plt.bar(keywords, counts, color=color_list)
            plt.xlabel("키워드")
            plt.ylabel("빈도")
            plt.tight_layout()
        else:
            plt.text(0.5, 0.5, "해당 날짜에 대한 데이터가 없습니다.", ha='center', va='center', fontsize=14)
        plt.tight_layout()
        pdf.savefig()
        plt.close()

        # 기사 목록 + 감성분석 + 요약
        if summary["articles"] is not None and not summary["articles"].empty:
            MAX_LINES_PER_PAGE = 30
            HEADER = f"기사 목록 + 감성분석/요약 ({report_date_str})"
            article_line_blocks = []
            for _, row in summary["articles"].iterrows():
                sentiment = "-"
                if sentiment_analyzer:
                    try:
                        sentiment = sentiment_analyzer(row["content"][:300])[0]["label"]
                    except:
                        sentiment = "-"
                summary_text = row["content"].split("다.")[0] + "다." if "다." in row["content"] else row["content"][:40]
                title = f"[{row['category']}] {row['title']} ({row['published_at']})"
                summary_lines = textwrap.wrap(f"요약: {summary_text}", width=70)
                sentiment_line = f"감성: {sentiment}"
                block = [
                    {"text": title, "style": "title"},
                    *[{"text": l, "style": "body"} for l in summary_lines],
                    {"text": sentiment_line, "style": "body"},
                    {"text": "", "style": "body"}
                ]
                article_line_blocks.append(block)

            current_lines = []
            line_count = 0
            for block in article_line_blocks:
                if line_count + len(block) > MAX_LINES_PER_PAGE and current_lines:
                    fig_height = max(3, min(len(current_lines) * 0.36 + 4, 24))
                    plt.figure(figsize=(8, fig_height))
                    plt.axis('off')
                    plt.text(0.5, 1, HEADER + "\n", fontsize=20, fontweight='bold', ha='center', va='top', fontname='NanumGothic')
                    y = 0.93
                    line_height = 0.036
                    for line in current_lines:
                        if line["style"] == "title":
                            plt.text(0.05, y, line["text"], fontsize=13, fontweight='bold', va="top", ha="left", fontname='NanumGothic')
                        else:
                            plt.text(0.05, y, line["text"], fontsize=11, va="top", ha="left", fontname='NanumGothic')
                        y -= line_height
                    pdf.savefig(bbox_inches='tight')
                    plt.close()
                    current_lines = []
                    line_count = 0
                current_lines.extend(block)
                line_count += len(block)
            if current_lines:
                fig_height = max(3, min(len(current_lines) * 0.36 + 4, 24))
                plt.figure(figsize=(8, fig_height))
                plt.axis('off')
                plt.text(0.5, 1, HEADER + "\n", fontsize=20, fontweight='bold', ha='center', va='top', fontname='NanumGothic')
                y = 0.93
                line_height = 0.036
                for line in current_lines:
                    if line["style"] == "title":
                        plt.text(0.05, y, line["text"], fontsize=13, fontweight='bold', va="top", ha="left", fontname='NanumGothic')
                    else:
                        plt.text(0.05, y, line["text"], fontsize=11, va="top", ha="left", fontname='NanumGothic')
                    y -= line_height
                pdf.savefig(bbox_inches='tight')
                plt.close()

        # 워드 클라우드
        if all_contents or all_keywords:
            plt.figure(figsize=(10, 5))
            text_for_wc = " ".join(extract_nouns(all_contents)) + " " + " ".join(all_keywords)
            wc = WordCloud(font_path="/usr/share/fonts/truetype/nanum/NanumGothic.ttf", width=800, height=400, background_color="white").generate(text_for_wc)
            plt.imshow(wc, interpolation='bilinear')
            plt.axis("off")
            plt.title("워드클라우드", fontsize=16, fontweight='bold')
            plt.tight_layout()
            pdf.savefig()
            plt.close()

        # 클러스터링 (KMeans, MLlib)
        if summary["embedding_pd"] is not None and summary["n_clusters"] > 1:
            embedding_pd = summary["embedding_pd"]
            n_clusters = summary["n_clusters"]
            cluster_colors = plt.cm.Set1.colors
            plt.figure(figsize=(8, 6))
            for i in range(n_clusters):
                idx = embedding_pd["cluster"] == i
                plt.scatter(embedding_pd.loc[idx, "pc1"], embedding_pd.loc[idx, "pc2"], label=f"Cluster {i+1}", color=cluster_colors[i % len(cluster_colors)])
            for i, row in embedding_pd.iterrows():
                plt.annotate(row["title"], (row["pc1"], row["pc2"]), fontsize=8)
            plt.title("KMeans 클러스터링 (임베딩 기반, MLlib)", fontsize=16, fontweight='bold')
            plt.xlabel("PC1")
            plt.ylabel("PC2")
            plt.legend()
            plt.tight_layout()
            pdf.savefig()
            plt.close()
            # 클러스터별 기사 표
            cluster_table = embedding_pd[["title", "cluster"]].rename(columns={"title": "기사", "cluster": "클러스터"})
            plt.figure(figsize=(8, min(0.5 * len(cluster_table) + 2, 10)))
            plt.axis('off')
            plt.title("클러스터 할당 (KMeans, MLlib)", loc='left', fontsize=14, fontweight='bold')
            table = plt.table(cellText=cluster_table.values, colLabels=cluster_table.columns, loc='center', cellLoc='left')
            table.auto_set_font_size(False)
            table.set_fontsize(9)
            table.auto_set_column_width(col=list(range(len(cluster_table.columns))))
            plt.tight_layout()
            pdf.savefig()
            plt.close()

    print(f"PDF 리포트 저장(로컬): {pdf_local_path}")

    # PDF를 HDFS로 업로드
    client = InsecureClient(WEBHDFS_URL, user='root')
    try:
        with open(pdf_local_path, 'rb') as pdf_file:
            client.write(f"{HDFS_PDF_DIR}/{pdf_filename}", pdf_file, overwrite=True)
        print(f"PDF 리포트 업로드(HDFS): {HDFS_PDF_DIR}/{pdf_filename}")
    except Exception as e:
        print(f"PDF HDFS 업로드 실패: {e}")

    # 원본 JSON 파일 HDFS 내에서 이동 (realtime → news_archive)
    try:
        file_list = client.list(REALTIME_DIR, status=True)
        for filename, meta in file_list:
            src = f"{REALTIME_DIR}/{filename}"
            dst = f"{ARCHIVE_DIR}/{filename}"
            client.rename(src, dst)
            print(f"HDFS 파일 이동: {src} -> {dst}")
    except Exception as e:
        print(f"HDFS 파일 이동 실패: {e}")

    spark.stop()
    print("작업 완료")

if __name__ == "__main__":
    args = parse_args()
    main(args.date)
'''
airflow/
├── dags/
│   └── scripts/
│       └── spark_daily_report.py     ← 이 파일 위치
        └── pdf folder                ← PDF 리포트 저장 폴더
├── data/                            
│   ├── realtime/                    ← JSON 원본 데이터
│   └── news_archive/                ← 처리 완료된 파일 이동                       


mkdir -p dags/scripts         # Spark 스크립트
mkdir -p data/realtime        # JSON 수신
mkdir -p data/news_archive    # 이동 대상
mkdir -p data              # PDF 출력

'''


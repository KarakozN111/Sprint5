import psycopg2         
import pandas as pd      
import gspread           
import os                

db_config = {
    'dbname': 'postgres',     
    'user': 'intern',         
    'password': 'intern',     
    'host': 'localhost',     
    'port': 5434             
}
google_sheet_id = '1IZGMJ06PRS9jpZlyx-A9axC9W8vu-j3FDDxryeY09F4'

credentials_path = '/Users/karakoznurgaliyeva/Desktop/BilimGroup/internship_first_semester_data_pack/dags/credentials.json'

def get_data_from_postgres(query):
    """Выгрузка данных из локального Postgres"""
    conn = psycopg2.connect(**db_config)

    df = pd.read_sql_query(query, conn)

    conn.close()

    return df

def upload_to_google_sheets(df, sheet_name):
    """Запись данных в Google Sheets через сервисный аккаунт"""

    for col in df.columns:

        if pd.api.types.is_datetime64_any_dtype(df[col]) or df[col].dtype == 'object':

            df[col] = df[col].astype(str)

    data_to_write = [df.columns.values.tolist()] + df.values.tolist()

    gc = gspread.service_account(filename=credentials_path)

    sh = gc.open_by_key(google_sheet_id)

    try:
        worksheet = sh.worksheet(sheet_name)

    except gspread.exceptions.WorksheetNotFound:
        worksheet = sh.add_worksheet(
            title=sheet_name,   
            rows="100",        
            cols="20"           
        )

    worksheet.clear()

    worksheet.update('A1', data_to_write)

    print(f"Данные успешно обновлены на листе: {sheet_name}")


if __name__ == "__main__":

    print("Запуск выгрузки данных")

    try:
        query_knowledge = "SELECT * FROM mart.mart_quality_of_knowledge;"

        df_knowledge = get_data_from_postgres(query_knowledge)

        upload_to_google_sheets(df_knowledge, "quality_of_knowledge")

        query_attendance = "SELECT * FROM mart.mart_attendance;"

        df_attendance = get_data_from_postgres(query_attendance)

        upload_to_google_sheets(df_attendance, "attendance")
        print("Все данные успешно залиты в Google Sheets!")

    except Exception as e:
        print(f"Произошла ошибка: {type(e).__name__}: {e!r}")
import preprocessing

if __name__ == "__main__":

    input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/Masterarbeit/Daten/DAX Xetra"
    pp = preprocessing.PreProcessor(input_folder)
    pp.init_rows_per_date()

    ticker = pp.rows.keys()[0]
    date = pp.rows[ticker].keys()[0]

    df = pp.get_dataframe_per_date(ticker, date)
    print(df.head())

    aggregation = pp.get_aggregation(df)
    print(aggregation)
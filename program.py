import Common.preprocessing as preprocessing

if __name__ == "__main__":

    input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/Masterarbeit/Daten/DAX MTF"
    pp = preprocessing.PreProcessor(input_folder)

    pp.init_rows_per_date()
    pp.save_rows_to_json()
        
    #pp.load_rows_per_date()
    
    #for i in range(len(pp.rows)):
    #    ticker = list(pp.rows)[i]
    #    for j in range(len(pp.rows[ticker])):
    #        date = list(pp.rows[ticker])[j]
    #        df = pp.get_dataframe_per_date(ticker, date)
    #        df = pp.get_filtered_dataframe(df)
    #        pp.get_aggregation(df)
    #print(pp.aggregations)
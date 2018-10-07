import Common.preprocessing as preprocessing

if __name__ == "__main__":

    input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/Masterarbeit/Daten/DAX Xetra"
    pp = preprocessing.PreProcessor(input_folder)

    #pp.init_rows_per_date()
    #pp.save_rows_to_json()
    pp.load_rows_per_date()
    pp.get_aggregations()
    pp.save_aggregations_to_csv()
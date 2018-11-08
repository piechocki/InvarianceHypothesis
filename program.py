import Common.preprocessing as preprocessing

if __name__ == "__main__":

    input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/" + \
        "4. Semester/Masterarbeit/Daten/DAX Xetra"
    additional_filter = {
        "xetra": ".DE_",
        "euronext": ".PA_",
        "bats": ".BS_",
        "turquoise": ".TQ_",
        "chix": ".CHI_"
    }

    pp = preprocessing.PreProcessor(input_folder)

    # pp.init_rows_per_date()
    # pp.save_rows_to_json()

    pp.load_rows_per_date()
    pp.init_aggregations()
    pp.save_aggregations_to_csv()

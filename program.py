#!/usr/bin/python
# -*- coding: utf-8 -*-
import Common.preprocessing as preprocessing

if __name__ == "__main__":

    additional_filter = {"xetra": "",
                         "euronext": "",
                         "bats": ".BS_",
                         "turquoise": ".TQ_",
                         "chix": ".CHI_"}
    folder_and_filter = [("DAX Xetra", "xetra"),
              ("DAX MTF", "bats"),
              ("DAX MTF", "turquoise"),
              ("DAX MTF", "chix"),
              ("CAC Paris", "euronext"),
              ("CAC MTF", "bats"),
              ("CAC MTF", "turquoise"),
              ("CAC MTF", "chix")]

    for i in range(8):
        i = 7
        input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/" + \
            "4. Semester/Masterarbeit/Daten/" + folder_and_filter[i][0]    

        pp = preprocessing.PreProcessor(input_folder, additional_filter[folder_and_filter[i][1]])

        # pp.init_rows_per_date()
        # pp.save_rows_to_json()

        pp.load_rows_per_date()
        pp.init_aggregations()
        pp.save_aggregations_to_csv()

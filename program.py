#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
This program module is the main entry point to the python based code of the
invariance hypothesis project. It provides access to all relevant functions
that can be used to preprocess TRTH datasets for the purpose of daily
aggregation for following data analysis and regressions.

Required packages are the preprocessing and pandashelper modules that are also
included in this project. Precise information about all packages with the used
version number can be found in the requirements.txt file.

The typical working procedure with this module is a cycle that consists of the
following five steps:
 - read all files to get the starting row for each date (*)
 - write these row numbers in a file (*)
 - load these row numbers from a file
 - aggregate the raw data (and get the distribution of data optionally)
 - save these aggregations to a csv file

(*) while these steps are done only once typically, the following three steps can
be iterated more quickly if the row numbers are accessible by a file easily,
but you can iterate all five steps in a row of course
"""

import Common.preprocessing as preprocessing

if __name__ == "__main__":

    # text filter for names of raw files
    additional_filter = {"xetra": "",
                         "euronext": "",
                         "bats": ".BS_",
                         "turquoise": ".TQ_",
                         "chix": ".CHI_"}
    # list with all subfolder names and the text filter corresponding with the trading venue
    folder_and_filter = [("DAX Xetra", "xetra"),
              ("DAX MTF", "bats"),
              ("DAX MTF", "turquoise"),
              ("DAX MTF", "chix"),
              ("CAC Paris", "euronext"),
              ("CAC MTF", "bats"),
              ("CAC MTF", "turquoise"),
              ("CAC MTF", "chix")]

    # iterate through all eight trading venues
    for i in range(8):

        # define input folder
        input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/" + \
            "4. Semester/Masterarbeit/Daten/" + folder_and_filter[i][0]  
        
        # instanciate new preprocessor class with input folder and text filter
        pp = preprocessing.PreProcessor(input_folder, additional_filter[folder_and_filter[i][1]])

        # do the desired preprocessing operations
        # pp.init_rows_per_date()
        # pp.save_rows_to_json()
        pp.load_rows_per_date()
        pp.init_aggregations()
        pp.save_aggregations_to_csv()

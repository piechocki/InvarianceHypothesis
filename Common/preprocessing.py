#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
The preprocessing module provides a class with several variables and functions
that are useful for aggregation of TRTH datasets to summarize tick and quote
data on a daily basis.

Required package is the pandashelper module that is also included in this
project.
"""

import os
import re
import json
import math
import Util.pandashelper as pandashelper


class PreProcessor:
    """
    The PreProcessor class is the container for one preprocessing task in
    which all collected data are stored. The initialization requires at least
    the input folder where the raw data are located. If the trading venue is
    a MTF you must define an additional filter.
    """
    def __init__(self, input_folder, additional_filter=""):

        self.input_folder = input_folder if input_folder[-1:] == \
            "/" else input_folder + "/"
        self.marketplace = self.get_marketplace() + (
            "" if additional_filter == "" else (
            " " + additional_filter.replace(
            "_", "").replace(".", "")))
        self.files = []
        self.bod = pandashelper.pd.Timestamp("1900-01-01 09:00:00.000")
        self.eod = pandashelper.pd.Timestamp("1900-01-01 16:30:00.000")
        for file in os.listdir(self.input_folder):
            if file.endswith(".csv.gz") and additional_filter in file:
                self.files.append(file)
        self.rows = {}
        self.aggregations_trades = pandashelper.get_empty_aggregation_trades()
        self.aggregations_quotes = pandashelper.get_empty_aggregation_quotes()
        self.distribution = pandashelper.pd.Series([])

    def init_rows_per_date(self):
        """
        Analyze raw data to get all row numbers for each day in the data.
        The result is a dictionary with one value per ticker that again
        represents a dictionary with one row number per day.
        """
        print("Getting rows (indices) per ticker and day ... ")
        rows = {}
        for i in range(len(self.files)):
            print("Processing file " + str(i + 1) + " of " +
                  str(len(self.files)) + " ...")
            source = self.input_folder + self.files[i]
            ticker = self.files[i].split('_')[1]
            rows[ticker] = pandashelper.get_dates_with_first_row(source)
        self.rows = rows

    def get_dataframe_per_date(self, ticker, date, date_next):
        """
        Function finds the source file in the input folder that belongs to
        the given ticker and returns the full path to the file as string.
        """
        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        first_row = self.rows.get(ticker, None).get(date, None)
        last_row = (self.rows.get(ticker, None).get(date_next, None) - 1) \
            if date_next is not None else (-1)
        return pandashelper.get_dataframe_by_rows(source, first_row, last_row)

    def get_source_by_ticker(self, ticker):
        """
        Function finds the source file in the input folder that belongs to
        the given ticker and returns the full path to the file as string.
        """
        r = re.compile("(\\w*)_" + ticker + "_(\\w*)")
        file = list(filter(r.match, self.files))[0]
        return self.input_folder + file

    def get_dataframe_per_iter(self, ticker, iterations):
        """
        Function queries the part of raw data that belongs to the given
        ticker and returns the query result as a dataset.
        """
        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        return pandashelper.get_dataframe_by_iter(source, iterations)

    def get_filtered_dataframes(self, df):
        """
        This function converts a dataframe with raw data into two separate
        dataframes, each one for trades and quotes. Furthermore it applies
        a first filter to improve the quality of trades and to exclude all
        data outside of official trading hours. Finally the columns will be
        converted to the right data type if it's different to string.
        """
        df.loc[:, "Time[G]"] = pandashelper.pd.to_datetime(
            df["Time[G]"], format="%H:%M:%S.%f")

        # add GMT offset plus difference between Berlin and London local time
        # trading hours of DAX Xetra and CAC Paris:
        #   9:00 am to 5:30 pm (Berlin local time)
        # trading hours of MTFs:
        #   8:00 am to 4:30 pm (London local time)        
        df.loc[:, "Time[G]"] = df["Time[G]"] + pandashelper.pd.Timedelta(
            hours=df["GMT Offset"].iloc[0]+int(
                self.marketplace != "DAX Xetra" and
                self.marketplace != "CAC Paris"))
        df = df.loc[(df["Time[G]"] >= self.bod) & (df["Time[G]"] <= self.eod)]

        df_trades = df.query("Type=='Trade' and " +
                             "Qualifiers.str.startswith(' [ACT_FLAG1]')")
        df_quotes = df.query("Type=='Quote'")

        for col in ["Price", "Volume"]:
            pandashelper.convert_column_to_numeric(df_trades, col)
        for col in ["Bid Price", "Bid Size", "Ask Price", "Ask Size"]:
            pandashelper.convert_column_to_numeric(df_quotes, col)

        return df_trades, df_quotes

    def get_splitted_dataframes(self, df, ticker, last_tail_length):
        """
        This function is included because of legacy reasons. It splits an
        input dataframe 'on the fly' without information about the rows of
        each day in the raw data. As a consequence this function becomes
        very slow for large dataframes.
        """
        date = str(df["Date[G]"].iloc[-1])
        index = self.rows[ticker][date]
        row = index % pandashelper.rows_limit_per_iter + last_tail_length
        return df.iloc[:row, :], df.iloc[row:, :]

    def init_aggregations(self):
        """
        This is the main method that calls the final aggregation function
        and iterates through all files with respect to the chunksize that
        is defined in the pandashelper module.

        The iterating loop cuts the dataframe only between rows of different
        dates (days) so that the aggregation function always gets all rows of
        one day at once.
        """
        print("Getting aggregations per ticker and day ...")
        for i in range(len(self.rows)):
            ticker = list(self.rows)[i]
            source = self.get_source_by_ticker(ticker)
            count_rows = self.rows[ticker][list(self.rows[ticker].keys())[-1]]
            max_iter = math.ceil(count_rows /
                                 pandashelper.rows_limit_per_iter)
            j = 0
            df_tail = pandashelper.pd.DataFrame()
            for df in pandashelper.get_dataframe_by_chunks(source):
                print("Processing iteration " + str(j + 1) + " of " +
                      str(max_iter) + " in file " + str(i + 1) + " of " +
                      str(len(self.rows)) + " ...")
                df = pandashelper.concat_dfs(df_tail, df)
                if j < max_iter - 1:
                    last_tail_length = len(df_tail)
                    df, df_tail = self.get_splitted_dataframes(
                        df, ticker, last_tail_length)
                df_trades, df_quotes = self.get_filtered_dataframes(df)
                self.init_aggregation(df_trades, df_quotes)
                j += 1

    def init_aggregation(self, df_trades, df_quotes):
        """
        Function requires two dataframes, each one for trades and quotes.
        It calculates an aggregation and appends it to the existing aggregation
        data structure in this class.
        """
        # calculating the distribution of the input data is optional. it only
        # makes sense if input dataframe doesn't contain more than one stock.
        #self.distribution = self.distribution.add(
        #    pandashelper.get_distribution(df_trades, 60), fill_value=0)
        #    #, df_trades["Date[G]"].iloc[0])
        aggregation_trades = pandashelper.get_new_aggregation_trades(
            df_trades)
        aggregation_quotes = pandashelper.get_new_aggregation_quotes(
            df_quotes)
        self.aggregations_trades = pandashelper.concat_dfs(
            self.aggregations_trades, aggregation_trades)
        self.aggregations_quotes = pandashelper.concat_dfs(
            self.aggregations_quotes, aggregation_quotes)

    def save_rows_to_json(self):
        """
        Save the row numbers dictionary in a json file for later iterations.
        The name of the ouput file is given by the trading venue.
        """
        j = json.dumps(self.rows)
        f = open(self.marketplace + ".json", "w")
        f.write(j)
        f.close()

    def load_rows_per_date(self):
        """
        Load row numbers from json file into a dictionary. The file name is
        derived from the trading venue that is derived again from the input
        folder and the additional filter.
        """
        f = open(self.marketplace + ".json")
        self.rows = json.load(f)
        f.close()

    def load_aggregations(self):
        """
        An aggregation of trades and quotes that is already done can be
        loaded from file to continue processing tasks within this class.
        """
        self.aggregations_trades = pandashelper.pd.read_csv(
            self.marketplace + " Trades.csv", header=0)
        self.aggregations_quotes = pandashelper.pd.read_csv(
            self.marketplace + " Quotes.csv", header=0)

    def save_aggregations_to_csv(self):
        """
        Save the aggregations of trades and quotes separately with the
        trading venue as file name. If there are data about the distribution
        of the data, it will be saved as well.
        """
        self.aggregations_trades.to_csv(
            self.marketplace + " Trades.csv", index=False)
        self.aggregations_quotes.to_csv(
            self.marketplace + " Quotes.csv", index=False)
        if not self.distribution.empty:
            self.distribution.to_csv(
                self.marketplace + " Verteilung.csv")

    def get_marketplace(self):
        """
        Gives the name of the trading venue derived from the input folder.
        """
        return self.input_folder[:-1].rsplit('/', 1)[1]

import os
import re
import pandas_helper

class PreProcessor:

    def __init__(self, input_folder):

        self.input_folder = input_folder if input_folder[-1:] == "/" else input_folder + "/"
        self.files = []
        for file in os.listdir(self.input_folder):
            if file.endswith(".csv.gz"):
                self.files.append(file)
        self.rows = {}
        self.aggregations = pandas_helper.get_empty_aggregation()

    def init_rows_per_date(self):

        rows = {}

        for i in range(len(self.files)):
            source = self.input_folder + self.files[i]
            ticker = self.files[i].split('_')[1]
            rows[ticker] = {}
            date = ""
            first_row = 0
            last_row = 0

            while True:
                first_row = 0 if last_row == 0 else last_row + 1
                date, last_row = pandas_helper.get_date_with_last_row(source, first_row)
                if last_row is None:
                    break
                rows[ticker][date] = (first_row, last_row)
        self.rows = rows

    def get_dataframe_per_date(self, ticker, date):
        
        r = re.compile("*_" + ticker + "_*")
        file = list(filter(r.match, self.files))[0]
        source = self.input_folder + file
        rows = self.rows.get(ticker, None).get(date, None)
        return None if rows is None else pandas_helper.get_dataframe_by_rows(source, rows[0], rows[1])

    def get_aggregation(df):

        aggregation = pandas_helper.get_new_aggregation(df)
        self.aggregations = pandas_helper.concat_dfs(self.aggregations, aggregation)
        return aggregation

        
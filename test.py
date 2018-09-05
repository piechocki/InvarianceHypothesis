# -*- coding: iso-8859-1 -*-
import pandas as pd

header = ("#RIC,Date[G],Time[G],GMT Offset,Type,L1-BidPrice,L1-BidSize,L1-AskPrice,L1-AskSize,L2-BidPrice,"
          "L2-BidSize,L2-AskPrice,L2-AskSize,L3-BidPrice,L3-BidSize,L3-AskPrice,L3-AskSize,L4-BidPrice,"
          "L4-BidSize,L4-AskPrice,L4-AskSize,L5-BidPrice,L5-BidSize,L5-AskPrice,L5-AskSize,L6-BidPrice,"
          "L6-BidSize,L6-AskPrice,L6-AskSize,L7-BidPrice,L7-BidSize,L7-AskPrice,L7-AskSize,L8-BidPrice,"
          "L8-BidSize,L8-AskPrice,L8-AskSize,L9-BidPrice,L9-BidSize,L9-AskPrice,L9-AskSize,L10-BidPrice,"
          "L10-BidSize,L10-AskPrice,L10-AskSize")
header = header.split(",")
iter_csv = pd.read_csv("C:/Users/marti/Desktop/Books_PSMGn.DE_20151001_20160101.csv/"
                       "Books_PSMGn.DE_20151001_20160101.csv", header=None, iterator=True, chunksize=10000)
data = pd.concat([chunk[chunk[1] == 20151002] for chunk in iter_csv])
data.columns = header
print(data[0:5])

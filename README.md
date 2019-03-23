# InvarianceHypothesis

This project contains several tools for analyzing trade and quote datasets from the Thomson Reuters Tick History (TRTH) as used in my master thesis with the title “Market Microstructure Invariance: An empirical analysis of European stocks” (original German title: „Marktmikrostruktur-Invarianz: Eine empirische Analyse europäischer Aktien“).

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. To use all functionalities you have to get likewise structured data compared to those descriped in my thesis.

### Prerequisites

All required packages are listed in the requirements.txt file (for Python) or in the import section of each script (for the required R packages). This project is developed and tested with Python version 3.6 and R version 3.5.1 only. The best way is to set up a new virtual environment with Anaconda, then start a command prompt in the location of the environment you've just created and execute the following snippet:

```
pip install -r requirements.txt
```

Of course you can install the packages listed in the requirements.txt file manually via the Anaconda GUI or via the environment configuration menu of your preferred IDE.

## Running the Program

Generally all sources in this repository are separated into the directories ./Python and ./R that contain all the code written in the particular language.

The main entry point in the Python code is the file program.py. If you configure your interpreter to execute this file you are given an instance of the preprocessor class by default. Out of this class you have access to all functionalities implemented in this project.

For running the regressions, plotting results or doing some z-tests you can execute each R-script stand-alone. The purpose of each script is given in the file name and furthermore there is a short description in every header of the scripts. There you can read about specific files you need before you can execute the script without any data issues.

### Python Modules

Apart from the instantiation of the program in program.py, all functions and methods are outsourced in further modules:

* preprocessing (in the folder ./Common) containing all "spanning" functions that are implemented with standard python basically
* pandashelper (in the folder ./Util) containing all direct data operations, implemented with specific data science functions from pandas mainly and numpy in part

These modules will be imported from the program.py already of course. You can access it's functions from the main program level via
```
preprocessing.your_function_call()
preprocessing.pandashelper.your_function_call()
```
or import the modules manually wherever you are with
```
import Common.preprocessing
import Util.pandashelper
```

## Built With

* [Visual Studio 2017](https://visualstudio.microsoft.com/de/downloads/) - The IDE used for Python related code
* [RStudio](https://www.rstudio.com/products/rstudio/download/) - The IDE used for R related code
* [Anaconda](https://www.anaconda.com/download/) - Management of virtual environments, especially to install the pandas package cleanly
* [pandas](https://pandas.pydata.org/) - Package used for data science stuff
* [NumPy](http://www.numpy.org/) - Package used for numeric and stochastic operations
* [TeX Live 2018](https://www.tug.org/texlive/acquire-netinstall.html) - Tex ressources used for compiling the thesis finally
* [Styles2Tex](https://github.com/piechocki/Styles2Tex) - Word Add-in to translate a docx file into tex compatible code

## Authors

* **M. Piechocki** - *Author of the thesis and of all files in this repository* - [piechocki](https://github.com/piechocki)

See the list of [contributors](https://github.com/piechocki/InvarianceHypothesis/contributors) who participated in this project.

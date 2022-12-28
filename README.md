# Socotra Data Mart Reports Demo

This repository has two components:
* `main.py`: sample script demonstrating use of the `socotra-datamart-reports` package
* `sample_queries.sql`: sample queries for common tasks and exploration

Since some reports require multiple queries and post-fetch processing, we offer `socotra-datamart-reports` as a quick start library. See [PyPI for details](https://pypi.org/project/socotra-datamart-reports/). 

## Running the main demo script

Install `requirements.txt` dependencies, which will bring in `socotra-datamart-reports`. Then create a `.env` file with the following contents:

```
REPORT_USER="your-datamart-username"
REPORT_PASSWORD="your-datamart-password"
REPORT_HOST="your-datamart-host"
REPORT_PORT="your-datamart-port"
REPORT_DATABASE="your-datamart-db"
```

You could skip `.env` and write credentials into the `creds` dictionary in `main.py`, but we recommend keeping credentials out of your code.

With your requirements installed and credentials set, you can simply run `main.py` (e.g. `python3 main.py`).
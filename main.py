import os
from dotenv import load_dotenv
from socotra_datamart_reports import OnRiskReport
from socotra_datamart_reports import AllPoliciesReport
from socotra_datamart_reports import TransactionFinancialImpactReport
from socotra_datamart_reports import FinancialTransactionsReport

load_dotenv()

if __name__ == "__main__":
     creds = {
          'user': os.environ.get('REPORT_USER'),
          'password': os.environ.get('REPORT_PASSWORD'),
          'port': os.environ.get('REPORT_PORT'),
          'host': os.environ.get('REPORT_HOST'),
          'database': os.environ.get('REPORT_DATABASE')
     }

     start_timestamp = 1659326400000
     end_timestamp = 1864596800000

     orr = OnRiskReport(creds)
     orr.write_on_risk_report(
          'personal-auto', start_timestamp,
          f'on_risk_report_{start_timestamp}.csv')

     apr = AllPoliciesReport(creds)
     apr.write_all_policies_report(
          'personal-auto', start_timestamp, end_timestamp,
          f'all_policies_report_{start_timestamp}-{end_timestamp}.csv')

     tfir = TransactionFinancialImpactReport(creds)
     tfir.write_transaction_financial_impact_report(
          'personal-auto', start_timestamp, end_timestamp,
          f'txn_financial_impact_report_{start_timestamp}-{end_timestamp}.csv')

     ftr = FinancialTransactionsReport(creds)
     ftr.write_financial_transactions_report(
          start_timestamp, end_timestamp,
          f'financial_txns_{start_timestamp}-{end_timestamp}.csv')

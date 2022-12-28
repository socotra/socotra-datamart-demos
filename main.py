import os
from dotenv import load_dotenv
from socotra_datamart_reports import OnRiskReport
from socotra_datamart_reports import AllPoliciesReport
from socotra_datamart_reports import TransactionFinancialImpactReport


load_dotenv()

if __name__ == "__main__":
     creds = {
          'user': os.environ.get('REPORT_USER'),
          'password': os.environ.get('REPORT_PASSWORD'),
          'port': os.environ.get('REPORT_PORT'),
          'host': os.environ.get('REPORT_HOST'),
          'database': os.environ.get('REPORT_DATABASE')
     }

     orr = OnRiskReport(creds)
     orr.write_on_risk_report('personal-auto', 1667278800000, 'on_risk_report_1.csv')

     apr = AllPoliciesReport(creds)
     apr.write_all_policies_report('personal-auto', 1659326400000, 1664596800000, 'all_policies_report_1.csv')

     tfir = TransactionFinancialImpactReport(creds)
     tfir.write_transaction_financial_impact_report(
          'personal-auto', 0, 1864596800000, 'transaction_financial_impact_report_1.csv')


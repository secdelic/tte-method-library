"""Fixed technical termination harness. No DGP, random draw or statistic."""
from pathlib import Path
import json,sys,time
HERE=Path(__file__).resolve().parent
folder=HERE/'technical_contract_test';folder.mkdir(exist_ok=False)
records={'TECHNICAL_TASK_STARTED':{'task_id':'TECHNICAL_TASK_STARTED','attempt_execution_status':'STARTED','actual_start_epoch':time.time(),'synthetic_harness_not_statistical_attempt':True},
 'TECHNICAL_TASK_NOT_STARTED':{'task_id':'TECHNICAL_TASK_NOT_STARTED','attempt_execution_status':'NOT_STARTED','synthetic_harness_not_statistical_attempt':True}}
(folder/'attempt_ledger.json').write_text(json.dumps({'records':records,'DEV_or_formal_M_or_B':0},indent=2),encoding='utf-8')
sys.exit(3)

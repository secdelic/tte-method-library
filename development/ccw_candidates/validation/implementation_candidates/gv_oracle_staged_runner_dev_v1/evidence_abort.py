"""Record only monitor-observed termination; never rerun to infer a failure."""
import json,time
def finalize_interrupted_ledger(path,receipt):
    if not path.exists():return 0
    obj=json.loads(path.read_text(encoding='utf-8'));changed=0
    records=obj['records'];rows=records.values()if isinstance(records,dict)else records
    for row in rows:
        if row.get('attempt_execution_status')=='STARTED':
            row.update({'attempt_execution_status':'ABORTED',
              'abort_reason':'MONITOR_OBSERVED_PROCESS_TERMINATION_WITHOUT_FINAL_ATTEMPT_RECORD',
              'last_durable_stage':'UNKNOWN_AFTER_LAST_DURABLE_RECORD','observed_termination_receipt':receipt,
              'termination_recorded_epoch':time.time(),'state_inferred_by_rerun':False})
            changed+=1
    if changed:path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return changed

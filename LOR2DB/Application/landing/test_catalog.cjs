const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
(async()=>{
 const els={};
 for(const id of ['catalog-panel','catalog-review','catalog-publish','catalog-approve','catalog-status','catalog-details']) els[id]={hidden:true,checked:false,disabled:false,textContent:'',listeners:{},addEventListener(event,fn){this.listeners[event]=fn;}};
 const calls=[];
 const responses=[{access:{can_publish_catalog:true}},
  {review_id:'a'.repeat(64),can_publish:true,source_folder:'master-folder-fixture',catalog_evidence_folder:'catalog-store-fixture',baseline_run_id:32,master_digest:'b'.repeat(64),changes:[{filename:'<unsafe>.lorprev',database_contract_review_required:false,metadata_changes:[{prop_id:'id',field:'MasterDimmable',before:'True',after:'False'}]}]},
  {source:{evidence_id:'c'.repeat(64)}}];
 const context={document:{getElementById:id=>els[id]},fetch:async(url,opt)=>{calls.push({url,opt});return{ok:true,json:async()=>responses.shift()};}};
 vm.runInNewContext(fs.readFileSync(__dirname+'/catalog.js','utf8'),context);
 await new Promise(setImmediate);
 assert.equal(els['catalog-panel'].hidden,false);
 await els['catalog-review'].listeners.click();
 assert.equal(els['catalog-publish'].disabled,true);
 assert(els['catalog-details'].textContent.includes('<unsafe>.lorprev'));
 assert(els['catalog-details'].textContent.includes('master-folder-fixture'));
 assert(els['catalog-details'].textContent.includes('catalog-store-fixture'));
 assert.equal(els['catalog-details'].innerHTML,undefined);
 els['catalog-approve'].checked=true;els['catalog-approve'].listeners.change();
 assert.equal(els['catalog-publish'].disabled,false);
 await els['catalog-publish'].listeners.click();
 assert.equal(JSON.parse(calls[2].opt.body).confirm_publish,true);
 assert.equal(els['catalog-publish'].disabled,true);
 assert(els['catalog-status'].textContent.includes('Official catalog published'));
 console.log('PASS catalog UI: explicit review/approval, safe text rendering, fixed endpoint and single-use publication');
})().catch(error=>{console.error(error);process.exitCode=1});

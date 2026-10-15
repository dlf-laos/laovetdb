import fs from 'node:fs';import crypto from 'node:crypto';import path from 'node:path';
const root=process.cwd();const file=process.env.LVSP_LOCAL_DATA_FILE||path.join(root,'apps/api/runtime/lvsp-data.json');const now=new Date().toISOString();const id=()=>crypto.randomUUID();
const companyId=id(),facilityId=id(),productId=id(),applicationId=id(),inspectionId=id(),sampleId=id(),shipmentId=id(),licenseId=id(),certificateId=id();
const resources={
 companies:[{id:companyId,legalNameLo:'ບໍລິສັດ ຕົວຢ່າງ ຈຳກັດ',legalNameEn:'Sample Veterinary Co., Ltd.',enterpriseNo:'DEMO-ENT-001',phone:'020 5555 5555',status:'ACTIVE',createdAt:now,updatedAt:now}],
 facilities:[{id:facilityId,nameLo:'ໂຮງງານຕົວຢ່າງ',nameEn:'Sample Veterinary Factory',facilityNo:'FAC-DEMO-001',status:'ACTIVE',createdAt:now,updatedAt:now}],
 applications:[{id:applicationId,caseNo:'APP/VM/DEMO/001',serviceCode:'VM-1003',applicantName:'Sample Veterinary Co., Ltd.',status:'TECHNICAL_REVIEW',createdAt:now,updatedAt:now}],
 products:[{id:productId,tradeName:'LVSP DEMO VACCINE',genericName:'Demo Antigen',productType:'VACCINE',lifecycleStatus:'REGISTERED',createdAt:now,updatedAt:now}],
 licenses:[{id:licenseId,licenseNo:'LIC-DEMO-001',licenseType:'FACTORY_OPERATING',holderName:'Sample Veterinary Co., Ltd.',status:'VALID',createdAt:now,updatedAt:now}],
 inspections:[{id:inspectionId,inspectionNo:'IN-DEMO-001',facilityName:'Sample Veterinary Factory',triggerType:'ROUTINE',status:'IN_PROGRESS',createdAt:now,updatedAt:now}],
 laboratory_samples:[{id:sampleId,sampleNo:'SMP-DEMO-001',sampleType:'Serum',sourceFacility:'Sample Farm',sampleStatus:'RECEIVED',createdAt:now,updatedAt:now}],
 disease_cases:[{id:id(),caseNo:'AH-DEMO-001',diseaseName:'Demo Disease',adminUnit:'Vientiane Capital',status:'SUSPECTED',createdAt:now,updatedAt:now}],
 trade_shipments:[{id:shipmentId,shipmentNo:'SHP-DEMO-001',operatorName:'Sample Veterinary Co., Ltd.',originCountry:'THA',status:'DECLARED',createdAt:now,updatedAt:now}],
 animals:[{id:id(),animalNo:'AN-DEMO-001',species:'Cattle',identifier:'RFID-0001',lifecycleStatus:'ACTIVE',createdAt:now,updatedAt:now}],
 aquaculture_stock_batches:[{id:id(),batchNo:'AQ-DEMO-001',species:'Tilapia',facilityName:'Sample Aquaculture Farm',status:'ACTIVE',createdAt:now,updatedAt:now}],
 certificates:[{id:certificateId,certificateNo:'CERT-DEMO-001',verificationToken:'demo-public-verification-token',status:'VALID',createdAt:now,updatedAt:now}]
};
const data={meta:{version:1,createdAt:now,updatedAt:now},resources,audit:[],outbox:[]};fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,JSON.stringify(data,null,2));console.log(`Demo data written to ${file}`);

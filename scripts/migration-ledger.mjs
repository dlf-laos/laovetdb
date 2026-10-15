export async function ledgerColumns(client){
 const result=await client.query("select column_name from information_schema.columns where table_schema='system' and table_name='schema_migration'");
 const columns=new Set(result.rows.map(x=>x.column_name));
 if(columns.has('filename')&&columns.has('checksum'))return {name:'filename',checksum:'checksum'};
 if(columns.has('migration_name')&&columns.has('sha256_checksum'))return {name:'migration_name',checksum:'sha256_checksum'};
 throw new Error('Migration ledger is absent or unsupported. Review the existing database before proceeding.');
}

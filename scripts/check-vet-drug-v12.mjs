import pg from 'pg';
const cs=process.env.DATABASE_URL;if(!cs){console.error('DATABASE_URL missing');process.exit(2)}
const pool=new pg.Pool({connectionString:cs,max:1,application_name:'lvsp-v12-check'});
try{
 const refs=await pool.query(`select domain_code,count(*)::int n from lookup.veterinary_drug_reference_term where is_active=true group by domain_code order by domain_code`);
 const col=await pool.query(`select 1 from information_schema.columns where table_schema='product' and table_name='product_regulatory_profile' and column_name='registration_number_source'`);
 const dup=await pool.query(`select registration_no,count(*) from product.product_regulatory_profile where registration_no is not null group by registration_no having count(*)>1 limit 1`);
 const sample=await pool.query(`select registration_no,dlf_date,issue_date,valid_years,expiry_date,registration_number_source from product.product_regulatory_profile order by updated_at desc nulls last limit 5`);
 console.log('V1.2 veterinary drug check');
 console.log('Reference terms:',Object.fromEntries(refs.rows.map(x=>[x.domain_code,x.n])));
 console.log('registration_number_source column:',!!col.rows[0]);
 console.log('duplicate registration numbers:',dup.rows.length);
 console.log('recent records:',sample.rows.length);
 if(!col.rows[0]||dup.rows.length)process.exitCode=1;
}finally{await pool.end()}

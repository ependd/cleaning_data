-- buat use show tables
select table_name
from information_schema.tables
where table_schema = 'public';

select * from layoffs;

-- buat table baru yang atributnya diambil dari table layoffs 
CREATE TABLE layoffs_stage1 (LIKE layoffs INCLUDING ALL);


-- insert seluruh data ke tabel baru
insert into layoffs_stage1
select * from layoffs;

-- kalo mau langsung copy struktur + data bisa pake
create table layoffs_stage1 as
select * from layoffs;

-- cara hapus table
drop table if exists layoffs_stage2 ;

-- 1. menghapus duplicate value
-- lihat data yang sama dulu
with remove_duplicate as (
select *,row_number () over (partition by company,"location",industry,
total_laid_off,percentage_laid_off,"date",stage,country,funds_raised_millions) as row_num
from layoffs_stage1
) select *
from remove_duplicate
where row_num > 1;

-- hapus pake cte yang kolab sama ctid
with remove_duplicate as(
select ctid, row_number () over(partition by company,"location",industry,
total_laid_off,percentage_laid_off,"date",stage,country,funds_raised_millions) as row_num
from layoffs_stage1
) delete from layoffs_stage1 ls 
using remove_duplicate rd
where rd.ctid=ls.ctid
and row_num > 1;

-- cara kedua
create table layoffs_stage2 (like layoffs_stage1 including all);
select * from layoffs_stage2;

-- tambah kolom baru
alter table layoffs_stage2 add column row_num int;

-- insert data
insert into layoffs_stage2 
select *,row_number () over (partition by company,"location",industry,
total_laid_off,percentage_laid_off,"date",stage,country,funds_raised_millions) as row_num
from layoffs;

select * from layoffs_stage2 
where row_num > 1;

-- hapus data yg sama by row_num
delete from layoffs_stage2 
where row_num > 1;

-- 2. Standaraisasi Data
-- menghapus space berlebih

select trim(company)as clean,company
from layoffs_stage1
order by 2;

select * from layoffs_stage2;

update layoffs_stage2 
set company = trim(company); 

-- penyelarasan kategori
select distinct industry  
from layoffs_stage2
order by 1;

select distinct industry 
from layoffs_stage2
where industry like 'Crypto%';

update layoffs_stage2 
set industry = 'Crypto'
where industry like 'Crypto%';

-- penyelarasan katogori dengan menghapus karakter ga penting
select distinct country 
from layoffs_stage2
order by 1;

select distinct country
from layoffs_stage2 ls 
where country like 'United States%';

update layoffs_stage2 
set country = 'United States'
where country like 'United States%';

-- atau bisa juga pake ini
update layoffs_stage2 
set country = trim(trailing '.' from country)
where country like 'United States%';

-- ubah tipe data dan format

-- saat akan update muncul eror, maka cara masalahnya
select distinct  "date" 
from layoffs_stage2
where "date" is not  null
and "date" !~ '^\d{1,2}/\d{1,2}/\d{4}$';

-- data tersebut bukan null, maka akan menjadi masalah
-- makanya kita ubah menjadi null
update layoffs_stage2 
set "date" = null 
where "date" !~ '^\d{1,2}/\d{1,2}/\d{4}$';

-- uji coba format
select "date" , to_date("date",'MM-DD-YYYY') 
from layoffs_stage2;

-- ubah format aja
update layoffs_stage2 
set "date" = to_date("date",'MM/DD/YY'); 

-- langsung ubah tipe column+format data
alter table layoffs_stage2 
alter column "date" type DATE
using to_date("date", 'MM-DD-YYYY');

select * from layoffs_stage2 ls 
order by industry asc;

-- 3. mengatasi mising value / null
-- cek mana ada yg mising value
select t1.company ,t1.industry , t2.industry 
from layoffs_stage2 t1
join layoffs_stage2 t2
on t1.company = t2.company 
where (t1.industry is null or t1.industry = '')
and t2.industry is not null;

-- ubah string kosong jadi null agar bisa di ubah
update layoffs_stage2 
set industry = null 
where industry = '';

-- ubah null sesuai data yang ada
update layoffs_stage2 t1
set industry = t2.industry 
from layoffs_stage2 t2
where t1.company = t2.company 
and t1.industry is null 
and t2.industry is not null;

-- 4. hapus banyak rows and column 
select *
from layoffs_stage2
where total_laid_off = 'NULL'
and percentage_laid_off = 'NULL';
-- disini tak terhitung sebagai null, tapi string yang bertuliskan null

delete 
from layoffs_stage2
where total_laid_off = 'NULL'
and percentage_laid_off = 'NULL';

select * from layoffs_stage2 ls ;

alter table layoffs_stage2 
drop column row_num;
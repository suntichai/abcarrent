# AB CARRENT นครศรีธรรมราช

เว็บแอปจัดการธุรกิจรถเช่า มีโหมดตัวอย่างในเบราว์เซอร์และโหมดออนไลน์ผ่าน Supabase โหมดออนไลน์ควรเปิดจาก GitHub Pages หรือ HTTPS URL ไม่ควรเปิดผ่าน `file://`

## ความสามารถ

- ภาพรวมรายได้เดือนนี้ จำนวนรถ รายการเช่า และลูกค้า
- แสดงจำนวนและรูปรถที่ไม่มีรายการเช่าทับซ้อนตลอดวันนี้บน Dashboard
- ปฏิทินรายเดือน แสดงวันที่มีรายการเช่า แตะวันที่เพื่อดูรถและเวลารับรถ
- สร้างรายการเช่าพร้อมเลือกผู้เช่า รถ วันเวลา มัดจำ และวิธีชำระเงิน
- คำนวณค่าเช่าเป็นรายวันและป้องกันการจองรถคันเดียวกันในช่วงเวลาทับซ้อน
- เปลี่ยนสถานะรายการและสถานะชำระเงิน พร้อมพิมพ์ใบเสร็จ
- เพิ่ม แก้ไข ปิด/เปิดให้เช่า และลบข้อมูลรถ พร้อมอัปโหลดรูปรถ
- เพิ่มและแก้ไขข้อมูลลูกค้า
- สมุดบัญชีรายรับ รายจ่าย ยอดสุทธิ และยอดรอชำระ
- ส่งออกรายการเช่าเป็น CSV สำหรับเปิดใน Excel
- โหมดตัวอย่างเก็บข้อมูลใน localStorage และโหมดออนไลน์เชื่อม PostgreSQL ผ่าน Supabase
- เข้าสู่ระบบผู้ดูแลด้วย Supabase Auth พร้อมตรวจสิทธิ์จากตารางผู้ดูแล
- ข้อมูลรถ ลูกค้า รายการเช่า และรายจ่ายอ่าน/บันทึกในฐานข้อมูลกลาง
- รูปรถอัปโหลดไป Supabase Storage

## ไฟล์ในชุด

- `index.html` หน้าระบบ
- `styles.css` รูปแบบหน้าจอและการปรับขนาดสำหรับมือถือ
- `app.js` การทำงานและข้อมูลตัวอย่าง
- `schema.sql` โครงสร้างฐานข้อมูล MySQL 8 สำหรับพัฒนาระบบเชื่อมต่อเซิร์ฟเวอร์
- `supabase-config.js` Project URL และ Publishable key สำหรับเว็บ
- `supabase/migrations/20261013000100_initial.sql` PostgreSQL schema, RLS, การกันเวลาจองรถชน และ bucket รูปรถ
- `supabase/migrations/20261013000200_customer_quotes_and_documents.sql` เพิ่มข้อมูลใบกำกับภาษี ไฟล์ลูกค้า ใบเสนอราคา และค่าใช้จ่ายระบุรถ
- `.github/workflows/deploy.yml` workflow เผยแพร่เว็บไซต์ไป GitHub Pages เมื่ออัปเดต branch `main`

## ตั้งค่า Supabase สำหรับเว็บออนไลน์

1. เปิด Supabase project แล้วไปที่ **SQL Editor** รัน `supabase/migrations/20261013000100_initial.sql` ก่อน จากนั้นรัน `supabase/migrations/20261013000200_customer_quotes_and_documents.sql`
2. ไปที่ **Authentication → Users** แล้วเพิ่มผู้ใช้แอดมินด้วยอีเมลและรหัสผ่าน
3. กลับไป **SQL Editor** รันคำสั่งด้านล่าง โดยแทนอีเมลตัวอย่างด้วยอีเมลแอดมินที่สร้างไว้:

   ```sql
   insert into public.ab_admins (user_id, display_name)
   select id, 'ผู้ดูแลระบบ'
   from auth.users
   where email = 'admin@example.com'
   on conflict (user_id) do nothing;
   ```

4. ใน **Authentication settings** ปิดการสมัครสมาชิกสาธารณะ เพราะระบบนี้ใช้บัญชีแอดมินที่เจ้าของสร้างเท่านั้น
5. อัปโหลด/commit ไฟล์ชุดนี้เข้า repository และให้ workflow GitHub Pages deploy เวอร์ชันใหม่
6. เปิดเว็บ GitHub Pages แล้วเข้าสู่ระบบด้วยบัญชีแอดมิน

`supabase-config.js` มี Publishable key ซึ่งออกแบบมาให้ฝังในเว็บได้ แต่การป้องกันข้อมูลขึ้นกับ RLS ใน migration นี้ ห้ามแทนที่ด้วย Secret key หรือ Service-role key ไฟล์ `schema.sql` ที่รากโฟลเดอร์เป็น MySQL สำหรับอ้างอิงเดิม อย่านำไปรันใน Supabase; ให้ใช้ไฟล์ migration ในโฟลเดอร์ `supabase/migrations/` แทน

ข้อมูลตัวอย่างที่เคยอยู่ใน localStorage จะไม่ถูกย้ายเข้า Supabase อัตโนมัติ เมื่อใช้โหมดออนไลน์ ให้เพิ่มรถ ลูกค้า และรายการจริงหลังเข้าสู่ระบบ ข้อมูลใน Supabase จะเป็นชุดกลางที่แอดมินที่ได้รับสิทธิ์มองเห็นร่วมกัน

## นำขึ้น GitHub และเปิดออนไลน์

1. สร้าง repository บน GitHub โดยเลือก `Public` หากต้องการใช้ Pages กับแผนฟรี
2. นำ **ไฟล์ทั้งหมดในโฟลเดอร์นี้** เข้า repository ที่ branch `main` โดยคงตำแหน่งไฟล์เดิม รวมถึง `.github/workflows/deploy.yml`
3. ใน repository เปิด **Settings → Pages** แล้วตั้ง **Build and deployment → Source** เป็น **GitHub Actions**
4. เมื่อ workflow `Deploy AB CARRENT to GitHub Pages` ทำงานสำเร็จ เปิด URL ที่แสดงใน **Settings → Pages** หรือในหน้า workflow run

หลังจากนั้น การ push การแก้ไขเข้า `main` จะเผยแพร่เว็บไซต์ให้อัตโนมัติ หาก repository ใช้ branch หลักชื่ออื่น ให้แก้ชื่อ branch ใน `.github/workflows/deploy.yml` ให้ตรงก่อน

GitHub Pages จะเผยแพร่ `index.html`, `styles.css`, `app.js` และ `supabase-config.js` ส่วน `README.md`, SQL migration และ workflow จะไม่ถูกใส่ไว้ในเว็บไซต์ที่เปิดสาธารณะ

## หมายเหตุการใช้งาน

โหมด Supabase ใช้ข้อมูลออนไลน์ร่วมกันและมีสิทธิ์แอดมินพื้นฐาน แต่ยังควรทดสอบนโยบาย RLS และสำรองข้อมูลก่อนใช้กับข้อมูลส่วนบุคคลจริง ระบบยังไม่ใช่ระบบบัญชีภาษีหรือใบกำกับภาษีอย่างเป็นทางการ


## Update for customer tax data, documents, and quotations

For an existing project, run `supabase/migrations/20261013000200_customer_quotes_and_documents.sql` in Supabase SQL Editor after the initial migration. It adds customer tax invoice fields, a private PDF bucket for identity and driving license files, per-car expense references, quote records, print timestamps, and a database rule that prevents paid bookings from being changed back to unpaid. Deploy the updated `index.html`, `styles.css`, `app.js`, and `supabase` folder to GitHub Pages. Address dropdowns load Thai province, district, and subdistrict data from the [thai-province-data repository](https://github.com/kongvut/thai-province-data).
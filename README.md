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
- เมนูตั้งค่ารวมข้อมูลบริษัท บัญชีธนาคาร และค่าเริ่มต้นวันเวลา/ประกัน
- ตั้งสำนักงานใหญ่หรือรหัสสาขา 5 หลัก พร้อมตราประทับที่เลือกแสดงบนเอกสาร A4
- แบบฟอร์มเช่าและใบเสนอราคาแสดงวันเวลาแบบ `dd/MM/yyyy HH:mm` และตรวจรถว่างก่อนบันทึก

## ไฟล์ในชุด

- `index.html` หน้าระบบ
- `styles.css` รูปแบบหน้าจอและการปรับขนาดสำหรับมือถือ
- `documents.css` รูปแบบใบเสร็จ ใบกำกับภาษี ใบเสนอราคา และรายชื่อลูกค้าขนาด A4
- `app.js` การทำงานและข้อมูลตัวอย่าง
- `schema.sql` โครงสร้างฐานข้อมูล MySQL 8 สำหรับพัฒนาระบบเชื่อมต่อเซิร์ฟเวอร์
- `supabase-config.js` Project URL และ Publishable key สำหรับเว็บ
- `supabase/migrations/20261013000100_initial.sql` PostgreSQL schema, RLS, การกันเวลาจองรถชน และ bucket รูปรถ
- `supabase/migrations/20261013000200_customer_quotes_and_documents.sql` เพิ่มข้อมูลใบกำกับภาษี ไฟล์ลูกค้า ใบเสนอราคา และค่าใช้จ่ายระบุรถ
- `supabase/migrations/20261014000100_company_banks_customer_phone.sql` เพิ่มข้อมูลบริษัท บัญชีธนาคาร ยอดรับชำระแยกบัญชี และใช้เบอร์โทรศัพท์เป็นรหัสลูกค้า
- `supabase/migrations/20261014040000_document_numbers_payments_notifications.sql` เพิ่มเลขรันเอกสาร การรับชำระหลายครั้ง และการแจ้งเตือนสำหรับแอดมิน

## ตั้งค่า Supabase สำหรับเว็บออนไลน์

1. เปิด Supabase project แล้วไปที่ **SQL Editor** รัน migration ตามลำดับ: `20261013000100_initial.sql`, `20261013000200_customer_quotes_and_documents.sql`, `20261014000100_company_banks_customer_phone.sql`, และ `20261014040000_document_numbers_payments_notifications.sql`
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
2. นำไฟล์เว็บไซต์เข้า repository ที่ branch `main` โดยคงตำแหน่งไฟล์เดิม
3. ใน repository เปิด **Settings → Pages** แล้วตั้ง **Build and deployment → Source** เป็น **Deploy from a branch** เลือก branch `main` และโฟลเดอร์ `/(root)` จากนั้นกด **Save**
4. เปิด URL ที่แสดงใน **Settings → Pages** เมื่อ GitHub เผยแพร่เว็บไซต์เสร็จ

หลังจากนั้น การ push การแก้ไขเข้า `main` จะเผยแพร่เว็บไซต์ให้อัตโนมัติ หากเลือกใช้ GitHub Actions แทนการเผยแพร่จาก branch ต้องเพิ่ม workflow สำหรับ GitHub Pages ใน `.github/workflows/` และตั้ง Source เป็น **GitHub Actions**

GitHub Pages จะเผยแพร่ `index.html`, `styles.css`, `documents.css`, `app.js` และ `supabase-config.js` ส่วน `README.md`, SQL migration และ workflow จะไม่ถูกใส่ไว้ในเว็บไซต์ที่เปิดสาธารณะ

## หมายเหตุการใช้งาน

โหมด Supabase ใช้ข้อมูลออนไลน์ร่วมกันและมีสิทธิ์แอดมินพื้นฐาน แต่ยังควรทดสอบนโยบาย RLS และสำรองข้อมูลก่อนใช้กับข้อมูลส่วนบุคคลจริง ระบบยังไม่ใช่ระบบบัญชีภาษีหรือใบกำกับภาษีอย่างเป็นทางการ


## Update for customer tax data, documents, and quotations

For an existing project, run `supabase/migrations/20261013000200_customer_quotes_and_documents.sql` in Supabase SQL Editor after the initial migration. It adds customer tax invoice fields, a private PDF bucket for identity and driving license files, per-car expense references, quote records, print timestamps, and a database rule that prevents paid bookings from being changed back to unpaid. Deploy the updated `index.html`, `styles.css`, `app.js`, and `supabase` folder to GitHub Pages. Address dropdowns load Thai province, district, and subdistrict data from the [thai-province-data repository](https://github.com/kongvut/thai-province-data).

Run `supabase/migrations/20261014000100_company_banks_customer_phone.sql` after the prior migrations. It makes the normalized phone number the customer ID, creates company and bank account settings, and links each booking payment to a receiving account. The app prints A4 receipts, quotations, and invoices using the saved company profile. A VAT invoice is enabled only when the company profile is marked VAT-registered; confirm the business details and tax treatment with the Revenue Department or an accountant before issuing official documents. Deploy `documents.css` with the other website files.

Run `supabase/migrations/20261014040000_document_numbers_payments_notifications.sql` after those migrations. It adds Buddhist-year document counters, booking payment history, and admin notifications.


## Source code organization

The application remains a single-page site. Feature code is maintained in `src/app/` modules, while the root `app.js` is the generated browser bundle used by `index.html` and GitHub Pages. After editing a source module, run `node scripts/build-app.js` to regenerate `app.js`. The build script uses only Node.js built-in modules.

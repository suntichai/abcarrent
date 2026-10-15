paymentForm=function(bookingId){
const booking=db.bookings.find(x=>x.id===bookingId);if(!booking)return;const bookingCustomer=customer(booking.customerId),bookingCar=car(booking.carId);
let editingId='';const closed=booking.status==='cancelled';
const dateValue=v=>{const d=new Date(v||Date.now());return isNaN(d.getTime())?todayISO():`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`};
const dateLabel=v=>{const d=new Date(v);return isNaN(d.getTime())?'—':`${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}/${d.getFullYear()}`};
const rows=paymentRows().filter(p=>p.bookingId===bookingId),sum=rows.reduce((n,p)=>n+Number(p.amount||0),0),balance=Number(booking.total)-sum;
const rowHtml=rows.map(p=>`<tr><td>${dateLabel(p.paidAt)}</td><td class="payment-method-cell">${esc(p.method||'—')}</td><td>${esc(db.bankAccounts.find(a=>a.id===p.bankAccountId)?.nickname||'—')}</td><td class="payment-amount-cell">${money(p.amount)}</td><td><button type="button" class="secondary-button orange-button" data-payment-edit="${esc(p.id)}" ${closed?'disabled':''}>แก้ไข</button> <button type="button" class="secondary-button danger-button" data-payment-delete="${esc(p.id)}" ${closed?'disabled':''}>ลบ</button></td><td class="payment-note-cell">${esc(p.note||'—')}</td></tr>`).join('')||'<tr><td colspan="6">ยังไม่มีรายการรับชำระ</td></tr>';
const warning=balance<0?`<div class="payment-overpaid">รับเงินเกินยอดบิล ${money(-balance)} แล้ว ยินยอมให้รับเงินเกินได้</div>`:'';
const modal=openModal(`แจ้งชำระเงิน · ${booking.id}`,`${customer(booking.customerId)?.name||''} · ยอดบิล ${money(booking.total)} · รับแล้ว ${money(sum)} · ${balance<0?'เกิน '+money(-balance):'คงเหลือ '+money(balance)}`,`<div class="payment-booking-overview"><div><small>ลูกค้า</small><b>${esc(bookingCustomer?.name||'—')}</b><span>${esc(bookingCustomer?.phone||'—')}</span></div><div><small>รถที่เช่า</small><b>${esc(bookingCar?.name||'ไม่พบข้อมูลรถ')}</b><span>${esc(bookingCar?.plate||'—')}</span></div><div><small>วันรับรถ</small><b>${dtFmt(booking.start)}</b></div><div><small>วันคืนรถ</small><b>${dtFmt(booking.end)}</b></div></div><div class="payment-summary"><b>สถานะชำระเงิน: ${booking.paid?'ชำระเงินแล้ว':'รอชำระ'}</b>${warning}</div><div class="table-wrap payment-history"><table><thead><tr><th>วันที่</th><th>ช่องทาง</th><th>บัญชีรับเงิน</th><th>จำนวนเงิน</th><th>จัดการ</th><th>หมายเหตุ</th></tr></thead><tbody>${rowHtml}</tbody></table></div><form id="payment-form"><div class="form-grid"><div class="field"><label>ช่องทาง <span class="required-star">*</span></label><select name="method" required ${closed?'disabled':''}><option>เงินสด</option><option>โอนเงิน</option><option>บัตรเครดิต</option><option>อื่นๆ</option></select></div><div class="field"><label>บัญชีรับโอน</label><select name="bankAccountId" ${closed?'disabled':''}>${bankAccountOpts()}</select></div><div class="field"><label>วันที่รับเงิน <span class="required-star">*</span></label><input name="paidAt" type="date" required value="${todayISO()}" ${closed?'disabled':''}></div><div class="field"><label>จำนวนเงิน (บาท) <span class="required-star">*</span></label><input class="payment-amount-input" name="amount" type="number" min="0.01" step="0.01" required ${closed?'disabled':''}></div><div class="field full"><label>หมายเหตุ</label><input name="note" placeholder="เช่น รับเงินมัดจำ" ${closed?'disabled':''}></div></div><div class="payment-overpaid" id="payment-overpaid-hint" hidden></div><div class="form-actions"><button type="button" class="secondary-button cancel-modal">ปิด</button><button class="primary-button" id="save-payment" ${closed?'disabled':''}>บันทึกรายการรับชำระ</button></div></form>`);
if(!modal)return;
const f=modal.querySelector('#payment-form'),method=f.elements.method,account=f.elements.bankAccountId,amount=f.elements.amount,hint=modal.querySelector('#payment-overpaid-hint');
const hintUpdate=()=>{const prior=paymentRows().filter(p=>p.bookingId===bookingId&&p.id!==editingId).reduce((n,p)=>n+Number(p.amount||0),0),extra=prior+(Number(amount.value)||0)-Number(booking.total);hint.hidden=!(Number(amount.value)>0&&extra>0);hint.textContent=hint.hidden?'':`ยอดรับสะสมเกินยอดบิล ${money(extra)} สามารถบันทึกได้`};
modal.querySelector('.cancel-modal').onclick=closeModal;
method.onchange=()=>{account.disabled=closed||method.value!=='โอนเงิน';account.required=method.value==='โอนเงิน';if(method.value!=='โอนเงิน')account.value=''};method.onchange();amount.oninput=hintUpdate;
modal.querySelectorAll('[data-payment-edit]').forEach(btn=>btn.onclick=()=>{const p=paymentRows().find(x=>x.id===btn.dataset.paymentEdit);if(!p)return;editingId=p.id;method.value=p.method||'เงินสด';method.onchange();account.value=p.bankAccountId||'';f.elements.paidAt.value=dateValue(p.paidAt);amount.value=Number(p.amount).toFixed(2);f.elements.note.value=p.note||'';modal.querySelector('#save-payment').textContent='บันทึกการแก้ไข';hintUpdate()});
const removePayment=async(id)=>{const payment=paymentRows().find(p=>p.id===id&&p.bookingId===bookingId);if(!payment)return toast('ไม่พบรายการรับชำระนี้');const confirmBox=openModal('ยืนยันลบรายการรับชำระ',booking.id,`<p>ลบรายการรับชำระวันที่ ${dateLabel(payment.paidAt)} จำนวน ${money(payment.amount)} หรือไม่</p><div class="form-actions"><button type="button" class="secondary-button cancel-modal">กลับ</button><button type="button" class="primary-button danger-button" id="confirm-payment-delete">ยืนยันลบ</button></div>`);if(!confirmBox)return;confirmBox.querySelector('.cancel-modal').onclick=()=>paymentForm(bookingId);const deleteButton=confirmBox.querySelector('#confirm-payment-delete');deleteButton.onclick=async()=>{deleteButton.disabled=true;const removedId=payment.id;let removedLocally=false;try{if(onlineMode){const {data,error}=await supabaseClient.from('booking_payments').delete().eq('id',removedId).select('id,booking_id');if(error)throw error;if(!data?.some(row=>row.id===removedId))throw new Error('ลบไม่ได้: ไม่พบรายการ หรือบัญชีนี้ไม่มีสิทธิ์ลบ')}db.payments=paymentRows().filter(p=>p.id!==removedId);removedLocally=true;const received=paymentRows().filter(p=>p.bookingId===bookingId).reduce((n,p)=>n+Number(p.amount||0),0);booking.paid=booking.paid||received>=Number(booking.total);if(onlineMode&&syncedState){syncedState.payments=(syncedState.payments||[]).filter(p=>p.id!==removedId);const {data,error}=await supabaseClient.from('bookings').update({paid:booking.paid}).eq('id',bookingId).select('id');if(error)throw error;if(!data?.some(row=>row.id===bookingId))throw new Error('ลบรายการแล้ว แต่ไม่สามารถปรับสถานะชำระเงินของบิลได้');const savedBooking=syncedState.bookings.find(b=>b.id===bookingId);if(savedBooking)savedBooking.paid=booking.paid;render()}else await persist();toast('ลบรายการรับชำระแล้ว');paymentForm(bookingId)}catch(error){if(removedLocally){render();toast(`ลบรายการแล้ว แต่ปรับสถานะบิลไม่สำเร็จ: ${error.message||'กรุณาตรวจสอบอีกครั้ง'}`);paymentForm(bookingId)}else{closeModal();toast(error.message||'ลบรายการรับชำระไม่สำเร็จ');paymentForm(bookingId)}}}};
modal.querySelectorAll('[data-payment-delete]').forEach(btn=>btn.onclick=()=>removePayment(btn.dataset.paymentDelete));
f.onsubmit=async e=>{
 e.preventDefault();
 const saveButton=modal.querySelector('#save-payment');
 if(saveButton.disabled)return;
 const d=Object.fromEntries(new FormData(f)),value=Number(d.amount);
 if(!(value>0))return toast('กรอกยอดเงินให้มากกว่า 0');
 if(d.method==='โอนเงิน'&&!d.bankAccountId)return toast('เลือกบัญชีรับโอน');
 const payment={id:editingId||crypto.randomUUID(),bookingId,amount:value,method:d.method,bankAccountId:d.bankAccountId||'',paidAt:new Date(d.paidAt+'T00:00:00').toISOString(),note:d.note||''};
 saveButton.disabled=true;
 try{
  if(onlineMode){
   if(editingId){
    const {data,error}=await supabaseClient.from('booking_payments').update({amount:payment.amount,payment_method:payment.method,bank_account_id:payment.bankAccountId||null,paid_at:payment.paidAt,note:payment.note||null}).eq('id',editingId).eq('booking_id',bookingId).select('id');
    if(error)throw error;
    if(!data?.some(row=>row.id===editingId))throw new Error('รายการรับชำระไม่ถูกบันทึก กรุณาตรวจสอบสิทธิ์แล้วลองอีกครั้ง');
   }else{
    const {error}=await supabaseClient.rpc('record_booking_payment',{p_payment_id:payment.id,p_booking_id:bookingId,p_amount:payment.amount,p_payment_method:payment.method,p_bank_account_id:payment.bankAccountId||null,p_paid_at:payment.paidAt,p_note:payment.note||null});
    if(error)throw error;
   }
   const {data,error}=await supabaseClient.from('booking_payments').select('*').eq('booking_id',bookingId).order('paid_at',{ascending:true});
   if(error)throw error;
   const freshRows=(data||[]).map(paymentFromDb);
   db.payments=[...paymentRows().filter(row=>row.bookingId!==bookingId),...freshRows];
   const total=freshRows.reduce((n,row)=>n+Number(row.amount||0),0);
   const paid=booking.paid||total>=Number(booking.total);
   const {data:savedBooking,error:bookingError}=await supabaseClient.from('bookings').update({paid}).eq('id',bookingId).select('id');
   if(bookingError)throw bookingError;
   if(!savedBooking?.some(row=>row.id===bookingId))throw new Error('โหลดรายการแล้ว แต่ปรับสถานะชำระเงินไม่สำเร็จ');
   booking.paid=paid;
   if(syncedState){
    syncedState.payments=[...(syncedState.payments||[]).filter(row=>row.bookingId!==bookingId),...freshRows.map(row=>({...row}))];
    const baseline=syncedState.bookings?.find(row=>row.id===bookingId);if(baseline)baseline.paid=paid;
   }
   render();
  }else{
   const old=editingId?paymentRows().find(row=>row.id===editingId):null;
   if(editingId&&!old)throw new Error('ไม่พบรายการรับชำระ');
   if(old)Object.assign(old,payment);else paymentRows().push(payment);
   booking.paid=booking.paid||paymentRows().filter(row=>row.bookingId===bookingId).reduce((n,row)=>n+Number(row.amount||0),0)>=Number(booking.total);
   await persist();
  }
  toast(editingId?'แก้ไขรายการรับชำระแล้ว':'บันทึกรับชำระเงินแล้ว');
  editingId='';
  paymentForm(bookingId);
 }catch(error){
  toast(error.message||'บันทึกรายการรับชำระไม่สำเร็จ');
 }finally{
  if(saveButton.isConnected)saveButton.disabled=false;
 }
};
};
bookingActions=function(id){const b=db.bookings.find(x=>x.id===id);if(!b)return;const editable=b.status!=='cancelled'&&new Date(b.start).setHours(0,0,0,0)>new Date().setHours(0,0,0,0),m=openModal(`รายการ ${b.id}`,`${customer(b.customerId)?.name||''} · ${car(b.carId)?.name||''}`,`<div class="receipt-info"><div><span>รับรถ</span><br>${dtFmt(b.start)}</div><div><span>คืนรถ</span><br>${dtFmt(b.end)}</div><div><span>ยอดรวม</span><br><b>${money(b.total)}</b></div><div><span>สถานะ</span><br>${statusLabel[b.status]||b.status}</div></div><div class="form-actions booking-actions"><button type="button" class="secondary-button" id="manage-payments">จัดการการชำระเงิน</button>${editable?'<button type="button" class="secondary-button" id="edit-booking-btn">แก้ไขรายการ</button>':''}${b.status==='cancelled'?'<span class="status status-cancelled">ยกเลิกแล้ว · แก้ไขไม่ได้</span>':'<button type="button" class="secondary-button danger-button" id="cancel-booking-btn">ยกเลิกรายการ</button>'}<button type="button" class="secondary-button cancel-modal">ปิด</button></div>`);if(!m)return;m.querySelector('.cancel-modal').onclick=closeModal;m.querySelector('#manage-payments').onclick=()=>paymentForm(id);if(editable)m.querySelector('#edit-booking-btn').onclick=()=>bookingForm(id);const cancel=m.querySelector('#cancel-booking-btn');if(cancel)cancel.onclick=()=>{const confirmModal=openModal('ยืนยันยกเลิกรายการ',`รายการ ${b.id}`,`<div class="cancel-warning"><p>เมื่อยกเลิกแล้วจะไม่สามารถแก้ไขรายการนี้ได้</p><p>ระบบจะไม่นำรายการนี้ไปตรวจสอบรถซ้ำในช่วงวันเวลาเดียวกัน</p></div><div class="form-actions"><button type="button" class="secondary-button cancel-modal">กลับ</button><button type="button" class="primary-button danger-button" id="confirm-cancel-booking">ยืนยันยกเลิกรายการ</button></div>`);if(!confirmModal)return;confirmModal.querySelector('.cancel-modal').onclick=()=>bookingActions(id);confirmModal.querySelector('#confirm-cancel-booking').onclick=async()=>{b.status='cancelled';await persist();toast('ยกเลิกรายการแล้ว รถคันนี้เปิดให้จองในช่วงเวลาดังกล่าว');closeModal();show('bookings')}}};

const {test,expect}=require('@playwright/test');
const photo=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNQTHUCAAFzAMlybM7OAAAAAElFTkSuQmCC','base64');
const fixture={name:'photo.png',mimeType:'image/png',buffer:photo};
test('capture delivers a prepared JPEG and permits selecting the same file again',async({page})=>{
  await page.goto('/tests/capture-dom.html');const input=page.getByLabel('Photo',{exact:true});
  await expect(input).toHaveAttribute('capture','environment');
  await input.setInputFiles(fixture);await expect(page.locator('#iris-app')).toContainText('data:image/jpeg;base64,');
  await expect(input).toHaveValue('');
  await input.setInputFiles(fixture);await expect(input).toHaveValue('');
});
test('invalid file reports validation without dispatching a photo',async({page})=>{
  await page.goto('/tests/capture-dom.html');const input=page.getByLabel('Photo',{exact:true});
  await input.setInputFiles({name:'bad.png',mimeType:'image/png',buffer:Buffer.from('invalid')});
  await expect.poll(()=>input.evaluate(el=>el.validationMessage)).not.toBe('');
  await expect(page.locator('#iris-app')).toContainText('No photo');
  await input.setInputFiles(fixture);await expect(page.locator('#iris-app')).toContainText('data:image/jpeg;base64,');
});
test('late decoding is discarded and its bitmap closed after unmount',async({page})=>{
  await page.goto('/tests/capture-dom.html');
  await page.evaluate(()=>{window.createImageBitmap=()=>new Promise(resolve=>{window.finishDecode=()=>resolve({width:1,height:1,close:()=>window.bitmapClosed=true});});});
  await page.getByLabel('Photo',{exact:true}).setInputFiles(fixture);
  await page.getByRole('button',{name:'Toggle capture'}).click();await expect(page.getByLabel('Photo',{exact:true})).toHaveCount(0);
  await page.evaluate(()=>window.finishDecode());await expect.poll(()=>page.evaluate(()=>window.bitmapClosed)).toBe(true);
  await expect(page.locator('#iris-app')).toContainText('No photo');
});
test('large photos are resized before delivery',async({page})=>{
  await page.goto('/tests/capture-dom.html');
  const png=await page.evaluate(()=>{const canvas=document.createElement('canvas');canvas.width=2000;canvas.height=1000;canvas.getContext('2d').fillRect(0,0,2000,1000);return canvas.toDataURL('image/png').split(',')[1];});
  await page.getByLabel('Photo',{exact:true}).setInputFiles({name:'large.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});
  await expect(page.locator('#iris-app')).toContainText('data:image/jpeg;base64,');
  const dimensions=await page.evaluate(async()=>{const data=Array.from(document.querySelectorAll('#iris-app *')).map(el=>el.textContent).find(text=>text.startsWith('data:image/jpeg;base64,')&&!text.includes('Toggle'));const bitmap=await createImageBitmap(await (await fetch(data)).blob());const size=[bitmap.width,bitmap.height];bitmap.close();return size;});
  expect(dimensions).toEqual([1600,800]);
});

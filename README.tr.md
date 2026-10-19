# Damage Workbench

Herhangi bir 5E kampanyasında kullanılmak üzere hazırlanmış yerel extension.
Kaynak kodu senaryoya veya karakter adlarına bağlı değildir.
Lisans: [MIT](LICENSE).

0.3.2: Cantrip'in Damage aksiyonunu doğrudan hedefe bırakmak veya seçili hedefe çalıştırmak da DWB isteği açar. Bırakılan hedef önceden seçili olmak zorunda değildir. Seçilen hasar satırı korunur; aynı satır/hedef için bekleyen istek yeniden kullanılır. Hedefsiz çift tıklama klasik akışta kalır.

Kullanıcıya özel aç/kapat ayarı, DMG effect sürükleme, native koşul/ifade değerlendirmesi ve yatay kaydırma bulunur. Otomatik sınıf hasarı önerileri kaldırıldı. Sağ tık menüsündeki Delete dice kullanılabilir. DTZ ve zar hücreleri daraltıldı; bitişik seçilen zarların vurgusu birleşir.
Zarlar tür boyutuna göre küçükten büyüğe, sonuçlar aynı sırada gösterilir.
Critical ve Non-critical ayrı alan başlıklarıdır; her alanın küçük bir + düğmesi
vardır. Atıştan sonra üst zar kutusu uzamaz; sonuçlar aynı sütunda ayrı kutudadır.
Tür dropdown'u en çok sekiz satır açılır ve kendi içinde kayar. Magical düğmesi
zar listesini yeniden oluşturmaz. Tür seçimi dropdown kontrolünü yok etmez.
Save atıştan sonra da görünür; Undo, reroll sonrasında da zar düzenlemeye döner.

Apply, panelde kabul edilen zarları tekrar post-roll dönüşümüne sokmadan native
sonuç/hasar uygulama akışına geçirir. Görünen toplam ham hasardır; hedefin
resist/immune gibi savunmaları native akışta ayrıca uygulanır.

## Kullanıcıya özel aç/kapat

**Options → Damage Workbench → Use Damage Workbench (this user)** altında
On/Off seç. Oyun ortasında da değiştirilebilir; değişiklik anında GM'ye iletilir
ve sonraki saldırıda kullanılır. `/dwb on` ve `/dwb off` aynı ayarı değiştirir.
Tercih o kullanıcının cihazında, kampanyanın yerel FG ayarlarında saklanır.
GM'nin veya başka oyuncuların seçimini değiştirmez. Varsayılan On'dur.

Off klasik FG akışını sürdürür; yeni DWB paneli açmaz. Henüz onaylanmamış
istekler kaldırılır. Açık/hazırlanmış bir atış kaybolmaz; tamamlanabilir veya
sohbetten yeniden açılabilir. Sahipsiz veya sahibi çevrimdışı karakterlerde
GM'nin kendi tercihi kullanılır.

## Kullanım

1. `dist/DamageWorkbench.ext` dosyasını FG veri klasöründeki `extensions` altına koy.
2. Önce ayrı bir test kampanyasında **Damage Workbench** seçeneğini aç.
3. Options → Damage Workbench altında **Ask GM** veya **Automatic** seç.
4. Weapon hit veya başarısız cantrip save sonrasında gerekiyorsa GM vuruşu onaylar.
5. Oyuncu panelde hasarı düzenler, Roll ile atar, gerekirse tek zara çift tıklayıp
   reroll yapar ve Apply ile uygular. Resist/immune hesabını native 5E akışı yapar.

Kilit düğmesi hasar türlerini düzenlemeye açar. Zarları tıklayarak seçebilir,
Ctrl + sol tık ile doğrudan silebilir ve türler arasında sürükleyebilirsin. Sabit değerler
yazılabilir; Ctrl + tekerlek ile değiştirilebilir. Critical sabit sayıları
çoğaltmaz. Reroll eski zar sonucunu yeni sonuçla değiştirir. Undo tüm atışı bırakıp
zarları yeniden belirlemeye döner; tur içindeki reroll sayacı korunur.

Zara sağ tıklayıp Delete dice seçerek zarı veya ait olduğu seçimi silebilirsin.
Ek onay sorulmaz. Ctrl + sol tık kısayolu da kullanılabilir.

Apply yapmadan her kapatışta yalnızca kapatan kullanıcının sohbetine yeniden
açma bağlantısı ve `/dwb` açıklaması gelir. Kapatmak hasar uygulamaz; düzenleme
sırasındaki yerel değişiklikler yeniden açılırken korunur.
Bekleyen hasarlar DB'ye yazılmaz; reload/yeniden açılışta sıfırlanır.

Save hem düzenleme hem sonuç ekranındadır; sonuçları değil yerleşimi kaydeder.
Açılan pencerede bir ad yazıp referansı Quick Actions'a sürükle.
Kaydı açık hasar paneline bırakmak veya Quick Actions'tan çalıştırmak mevcut
yerleşimi tamamen değiştirir. Kapalı panel varken kayıt hasar uygulamaz.

`/dwb demo` hedefe hasar uygulamayan bir gösterim açar.

## Kod ve test

`python tools/build.py` kurulabilir paketi üretir. Geliştirme testleri için
`requirements-dev.txt` içindeki Lua çalışma zamanı gerekir. Test kuklası ve
kampanya kopyaları yayın paketine dahil edilmez.

`python tools/build.py --source` temiz kaynak arşivini de üretir. Yalnızca
`dist/DamageWorkbench-Source.zip` arşivi kod paylaşımı için hazırlanmıştır;
yerel `.reference` ve `.private` klasörlerini paylaşma.

Ek hasar için effect aksiyonunu panele sürükle. DMG türleri, IF/IFT ve diğer
kurulu koşullar native effect sisteminde saldırgan/hedef ve melee/ranged
bağlamıyla değerlendirilir. `weapon` silahın türünü miras alır. Divine Smite
örneği humanoid için 2d8, fiend/undead için 3d8 radiant ekler. UPCAST=2 iken
`{_[UPCAST]+2_}d6 radiant` 4d6 olur. Upcast için caster'ın gerçek effect
aksiyonunu sürükle; bağlam çözülemiyorsa tahmin yapılmaz.

Otomatik Smite/Sneak Attack önerisi veya sınıf özelliğinden eklenen hasar yoktur.
Eklenen zarlar normal şekilde silinebilir. Drop gerçek CT effect'i eklemez,
spell slot harcamaz veya concentration başlatmaz; bunları karakterin normal
spell/effect akışında yönetirsin. Koşullar drop anındaki hedefe göre hesaplanır.
DTZ'lerin altındaki çubuk, tutamacı sürükleyerek, çubuğa tıklayarak veya fare
tekerleğiyle piksel bazında yana kaydırır.

16 model/derleme testi mevcut. Native kontroller ve kapsam sınırları
[test kaydında](TESTING.md) yer alır. Ayrı oyuncu istemcisi henüz doğrulanmadı.
Paneldeki 2D zarlar standart ikonlardır; hasar türüne atanmış skin gerçek 3D
atışta kullanılır.

Kod veya paket GitHub'a gönderilmedi.

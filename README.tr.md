# Damage Workbench

Fantasy Grounds Unity 5E'de silah ve cantrip hasarını incele, zarları düzenle,
gizli atış yap ve hazır olduğunda sonucu uygula.

[English guide](README.md) · [MIT Lisansı](LICENSE)

![Kilitli hasar hazırlama paneli](docs/screenshots/damage-setup.png)

Görüntüler `/dwb demo` ile açılan örnek panelden alınmıştır. Görünüm, aktif FG temasına göre değişir.

## Hasar panelini aç

1. Bir hedef seçip silah veya cantrip saldırısı yap ya da hasar veren cantrip'e
   karşı hedefe kurtarma atışı yaptır.
2. İsabet veya başarısız kurtarma bir hasar isteği oluşturur. **Ask GM** modunda
   GM son değiştiricileri çözüp **Confirm HIT** düğmesine basar. **Cancel** isteği
   kapatır. **Automatic** modunda panel bu onay beklenmeden açılır.
3. Hasarı düzenle, **Roll** ile at, sonuçları incele ve **Apply Damage** ile uygula.

GM, **Options → Damage Workbench → Confirm hits before damage adjustment**
ayarından **Ask GM** veya **Automatic** seçer.

Cantrip'in **Damage** aksiyonunu doğrudan da kullanabilirsin: hedef seçiliyken
çalıştır veya bir yaratığın üzerine sürükleyip bırak. Üzerine bıraktığın hedefin
önceden seçili olması gerekmez. Seçtiğin hasar aksiyonu korunur; aynı aksiyon ve
hedef için bekleyen bir istek varsa yeniden açılır. Seçili hedef veya bırakılan
hedef olmadan çalıştırılan hasar aksiyonu klasik FG akışında devam eder.

Kurtarma isteyen cantrip'lerde başarılı kurtarma normalde DWB isteği oluşturmaz.
Damage'ı doğrudan kullanmak ayrı bir işlemdir; yeni saldırı veya kurtarma atışı yapmaz.

## DWB kullanıp kullanmayacağını seç

Her kullanıcı **Options → Damage Workbench → Use Damage Workbench (this user)**
ayarını oyun sırasında da değiştirebilir. Varsayılan **On**'dur. Tercih o
kullanıcının bilgisayarında, kampanya için kaydedilir ve anında GM'ye iletilir.
Sonraki işlemlerde yeni tercih kullanılır.

**Off**, klasik FG akışını kullanır ve henüz onaylanmamış DWB isteklerini kaldırır.
Hazırlanmış veya atılmış bir hasar paneli tamamlanabilir ya da yeniden açılabilir.
Karakterin sahibi çevrimiçiyse onun tercihi; karakter sahipsizse veya sahibi
çevrimdışıysa GM'nin tercihi kullanılır.

## Hasar türlerini ve zarları düzenle

Her hasar türünün ayrı bir kutusu (DTZ) vardır. Saldırı adı **Critical** düğmesinin
yanındadır. Sağ üstteki kilit başlangıçta kilitlidir. Kilide tıklamak **hasar
türleri listesini** düzenlemeye açar; liste kilitliyken de zar ekleyip düzenleyebilirsin.

| İşlem | Nasıl yapılır? |
| --- | --- |
| Hasar türü ekle | Kilidi aç, **+** düğmesine bas ve açılır listeden tür seç. |
| Türü değiştir | Kilidi aç ve tür listesini kullan. Aynı bölümde bir tür tekrarlanamaz. |
| Hasar türünü kaldır | Kilidi aç ve kutunun kırmızı çöp kutusu düğmesine iki kez bas. |
| Zar ekle | Masaüstündeki zarları istediğin tür kutusuna sürükle. |
| Hasar aksiyonu ekle | Aksiyonu henüz atılmamış panelin herhangi bir yerine bırak. |
| Zar seç | Bir tür kutusundaki zarlara tıkla. Tekrar tıklamak seçimi kaldırır. |
| Zar taşı | Seçili zarları başka bir tür kutusuna sürükle. |
| Zar sil | Zara sağ tıklayıp **Delete dice** seç. Seçili grup birlikte silinir. |
| Kısayolla sil | **Ctrl + sol tık** ile zarı veya ait olduğu seçili grubu sil. |
| Sabit bonusu değiştir | Sayıyı yaz veya üzerinde **Ctrl + mouse wheel** kullan. |
| Yatay kaydır | Tür kutuları veya zarların üzerindeyken dikey mouse wheel kullan; alt çubuğu sürükleyebilir veya çubuğa tıklayabilirsin. |

Açık hasar türü listesi kendi içinde kayar. Zarlar küçük türden büyüğe sıralanır;
sonuçlar da aynı sırayı korur.

**Critical**, Critical ve Non-critical hasarı ayırır. Critical bölümündeki uygun
zarlar ikiye katlanır; sabit bonuslar katlanmaz. Katlanmaması gereken zarları
**Non-critical** bölümüne koy. Critical'ı kapatmak bölümleri birleştirir;
yeniden açmak mevcut zarları kritik hasara uygun olarak sınıflandırır.

**Magical** ilk aksiyondan gelir ve atıştan önce değiştirilebilir. Sonradan
yaptığın drop'lar bu düğmeyi otomatik değiştirmez. Atmadan önce her kutu için
bir hasar türü seç.

![Kilit açıkken Critical ve Non-critical hasar türleri](docs/screenshots/damage-types-critical.png)

Kilit açıkken her bölümün **+** düğmesiyle tür ekleyebilir, açılır listelerden tür değiştirebilirsin.

## Smite, Sneak Attack ve diğer hasar effect'lerini ekle

Karakterin Actions sayfasındaki effect aksiyonunu veya bir effect kaydını,
atıştan önce hedefli hasar paneline bırak. DWB, eşleşen **DMG** bileşenlerini
hasar türleriyle birlikte ekler. Bu bonusları kendin eklersin; DWB otomatik
sınıf özelliği önerileri sunmaz.

| Effect metni | Eklenen hasar |
| --- | --- |
| `Sneak Attack; DMG: 2d6 weapon;` | Silahın hasar türüyle 2d6. |
| `€ Improved Divine Smite; DMG: 1d8 radiant, melee` | Eşleşen yakın dövüş aksiyonunda 1d8 radiant. |
| `$ Divine Smite (lvl 1); DMG: 2d8 radiant, melee; IFT: TYPE(undead, fiend); DMG: 1d8 radiant, melee` | Eşleşen yakın dövüş aksiyonunda humanoid'e 2d8, fiend/undead'e 3d8 radiant. |
| `Branding Smite (Caster); (C); DMG: {_[UPCAST]+2_}d6 radiant` | UPCAST=2 için 4d6 radiant. Upcast değerinin çözülebilmesi için caster'ın gerçek effect aksiyonunu sürükle. |

**IF/IFT**, **ELSE**, hedef türü ve melee/ranged gibi koşullar, kurulu effect
sistemiyle mevcut saldırgan ve hedef için değerlendirilir. Upcast ifadesi
çözülemiyorsa drop reddedilir. Koşullar drop anında kontrol edilir; ilgili durum
değişirse eklenen hasarı kaldırıp effect'i yeniden bırak.

Eklenen zarlar düzenlenebilir ve silinebilir. Effect bırakmak onu combat tracker'a
eklemez, spell slot harcamaz veya concentration başlatmaz. Bunları karakterin
normal spell/effect kontrollerinden yönet.

## Roll, reroll, Undo ve Apply

**Roll**, zarları gizli atar. Sonuçlar, ilk zar kutularının altında ayrı kutularda
görünür; henüz hasar uygulanmaz.

Bir sonuç zarına çift tıklayıp onaylayarak **reroll** yap. Yeni sonucu kullanman
gerekir; o zarın eski sonucuna dönemezsin. Onay penceresi, karakterin mevcut
combat turundaki reroll sayısını gösterir.

**Undo**, reroll sonrasında da tüm atışı bırakıp zar düzenlemeye döner. Yanlış
zarları seçtiysen hasarı yeniden hazırlamak için kullan. Turun reroll sayacı korunur.

**Apply Damage**, kabul ettiğin sonuçları sohbete gönderir ve hedefe hasarı uygular.
Panel ham hasarı gösterir; resistance, immunity ve diğer hedef savunmaları alınan
gerçek hasarı azaltabilir. Apply sonrasında bekleyen DWB isteği sona erer.

![Ayrı kutularda kritik ve normal atış sonuçları, Undo ve Save](docs/screenshots/damage-results.png)

Üstte hazırlanan zarlar, altta sonuçlar görünür. Bu örnek hedefsiz demodur: **Apply** kapalıdır ve hiçbir hedef hasar almaz.

## Paneli kapat ve yeniden aç

**X** ile kapatmak hasar uygulamaz. Apply öncesindeki her kapatışta **yalnızca
senin sohbetine** bir hatırlatma ve yeniden açma bağlantısı gelir. Bağlantıya
tıkla veya `/dwb` kullanarak bekleyen hasarı aç. Atış öncesi düzenlemelerin korunur.

Bekleyen paneller ve atış sonuçları mevcut oturum boyunca tutulur. Reload veya
yeniden başlatma bunları temizler; önce bekleyen hasarı tamamla.

## Hasar yerleşimini kaydet

**Save**, atıştan önce ve sonra kullanılabilir. Bir ad girip adlandırılmış
tutamacı **Quick Actions** alanına sürükle. Atış sonuçları değil, yerleşim kaydedilir.

Kaydı henüz atılmamış bir panele bırak veya böyle bir panel açıkken Quick Action'ı
çalıştır. Mevcut yerleşimin tamamı değiştirilir. Panel kapalıyken kaydı çalıştırmak
yalnızca kullanım mesajı gösterir.

![Hasar yerleşimini adlandır ve tutamacı Quick Actions alanına sürükle](docs/screenshots/save-layout.png)

## Sohbet komutları

| Komut | İşlev |
| --- | --- |
| `/dwb` | Bekleyen hasarı yeniden aç. |
| `/dwb on` | Bu kullanıcı için DWB'yi aç. |
| `/dwb off` | Bu kullanıcı için klasik FG akışına geç. |
| `/dwb demo` | Hedefsiz örnek panel aç. Roll ve Undo denenebilir; Apply devre dışıdır. |

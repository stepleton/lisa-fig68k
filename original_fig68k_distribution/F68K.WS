                        6800° fig-FORTH

    Thió versioî oæ FORTÈ implementó thå fig-FORTÈ modeì presenteä iî thå FORTÈ 
Interesô Group'ó Installatioî Manuaì iî codå foò thå Motorolá 6800° microprocessor®  
Thå listinç presenteä herå afteò ió identicaì tï thå versioî 1.° oæ Kennetè Mantei¬ 
excepô thaô thió ió iî standarä Motorolá assembleò format® Thå transcriptioî waó donå 
bù memberó oæ thå Dutcè fiç chapter¬ aó iô waó felô thaô thió formaô woulä greatlù 
enhancå thå usability®  Then this introduction was made to match the new listing. 
Iô ió á 6´ Ë version,usinç conventionaì two-bytå addresses,whicè doeó 
noô makå uså oæ thå 32-biô addressinç capabilitieó oæ thå 68000® Primitivå wordó arå 
locateä aô 2000-2500H,witè thå six-bytå inneò interpreteò appendeä tï eacè word® 
Constantó  anä variableó ruî froí 2500-2700H® Mosô oæ thå constantó relatå tï 
hardwarå anä iô seemeä desirablå tï locatå theså oî thå USEÒ page¬ Sï á ne÷ 
primitive¬ (USERCONSTANT© waó defineä thaô requireó nï modificatioî tï FORTÈ sourcå 
material,buô getó constantó froí thå USEÒ page® Thå resô oæ thå kernaì runó froí 
2700-3000H® Thå conditionaì compiler,matè words,outpuô words,anä VLISÔ ruî froí 3000-
3400H® Disã I/Ï anä boot-uğ codå runó froí 3400-3700H® FORTÈ ió entereä bù á jumğ tï 
thå COLÄ labeì (aô 364E).oò thå warm starô aô thå labeì WARÍ (aô 368A).

  Thå 180² modeì useä aó á startinç poinô assumeä 128-bytå buffeò blocks® 
Modificationó werå madå iî +BUÆ tï handlå automaticallù 1024,512¬ anä 25¶ bytå 
bufferó aó well® "84¢ waó replaceä bù "B/BUÆ ´ « "® Similarly,thå nulì worä X,waó 
modifieä tï handlå 1,2,4,aó welì aó thå originaì ¸ buffers/screen¬ "7¢ waó replaceä 
bù "B/SCÒ ± -"¬ B/BUÆ anä B/SCR,no÷ userconstantó oî thå USEÒ pagå neeä onlù bå 
choseî tï givå 102´ bytes/screen.

   CREATÅ originallù assumeä thaô uncheckeä dictionarù growtè woulä ruî intï thå 
computatioî stack® Tï enablå thå latteò tï bå locateä arbitrarily¬ á USEÒ variable¬ 
DICTLIMIT,haó beeî introduced® CREATÅ no÷ checkó tï bå surå thå dictionarù ió noô 
exceedinç DICTLIMIT,ratheò thaî encounterinç thå computatioî stack® tï ensurå thaô 
LFA'ó falì oî eveî addresses¬ aó requireä bù thå 68000,CREATÅ haó alsï beeî 
modifieä tï inserô 0° filì byteó aheaä oæ NFA'ó wheî necessary.

   Kennetè Manteé changeä CMOVÅ tï aî intelligenô movå iî thió version¬ hencå iô doeó 
noô agreå witè thå fiç standarä anä cannoô bå useä bù FILL® Tï abidå bù thå fiç 
standards you may perform the modification suggeted in the listing. 

Thå 6800° ió considereä á worä addressinç processor¬ sï ¡ anä À dï noô handlå odä 
addresses® Howeveò CÀ C¡ C¬ CMOVÅ alì worë aó expecteä (witè thå aforementionneä 
restriction with respect to CMOVE)

   Á ne÷ codå word,C=,haó beeî addeä thaô functionó likå ½ excepô thaô onlù thå lo÷ 
byteó arå compared® Thió ió useä iî EXPECÔ á couplå oæ timeó tï replacå =® EXPECÔ 
haó alsï beeî modifieä tï geô itó backspace-keyiî anä backspace-outpuô ASCIÉ codeó 
froí thå USEÒ page,wherå theù arå calleä BKSPKEÙ anä BKSPEMIT.


   +ORIGIÎ accesseó thå samå bootuğ parameters,exactlù aó showî oî SCR£ 7¹ anä 9· 
oæ thå Installatioî Manual® However,thå bootupó arå no÷ locateä iî COLD,ratheò thaî 
iî fronô oæ FORTH.

   22´ wordó arå listeä iî thå glossarù oæ thå Installatioî Manual¬ Modificatioî oæ ´ 
oæ theseº CMOVE,FILL,EXPECÔ anä CREATÅ haó beeî metioneä above® 1· otheò glossarù 
wordó havå beeî ommitteä iî thió implementationº (ABORT© ;CODÅ .CPÕ  FLUSÈ TASË TRIAÄ 
DR±  (froí thå generaì FIG-model© anä LISÔ MOÎ MOVÅ BLOCK-REAÄ BLOCK-WRITÅ NEXÔ POĞ 
PUSÈ anä PUÔ (onlù compareä witè thå 180² source).
 1¸ wordó noô appearinç iî thå glossary,arå added:
ORIGIÎ CURRENÔ C/Ì C½ !CODÅ (VAR© (CONST© (USERCONSTANT© (NEST© 
BKSPKEÙ BKSPEMIÔ DICTLIMIÔ EMITSUÂ KEYSUÂ ?TERMSUÂ CRSUÂ anä R/WSUB® 

   Wå ascheweä thå uså oæ advanceä featureó iî thå assembleò sucè aó macroó aó theù 
maù noô bå availablå oî alì assemblers® Actuallù wå useä ourselveó thå A68ë publiã 
domaiî CP/Í crosó assembleò froí QUELO® Somå labeló iî repeaô loopó havå beeî 
replaceä bù thå SEÔ directive® Thió releaveó thå burdeî oî thå symboì tablå (iî ouò 
caså crucial© anä iô ió alsï cleaneò becauså iô sho÷s thaô thå labeì ió strictlù 
local.
.CĞ 5Š
                                REGISTEÒ ALLOCATION

   Addresó registeró arå numbereä A0..A· iî thå 68000  anä datá registeró arå 
D0...D7® Fivå addresó registeró arå dedicateä pointers® A³ ió CS, thå computatioî 
stacë pointeò whicè growó towarä lo÷ memorù anä ió alwayó pointinç aô thå higè 
ordeò (buô loweò memory) bytå oæ thå toğ 2-bytå stacë cell® A´ ió IP,thå 
instructioî pointer,whicè ió incrementeä wheî used¬ tï poinô tï thå nexô cell® Aµ 
ió thå worä pointer,loadeä aó usuaì viá IĞ anä incrementeä aó used¬ A¶ ió US¬ thå 
USEÒ pagå pointeò witè whicè offseô addresseó arå useä tï locatå USEÒ variableó anä 
userconstants® A· ió RÓ ,thå returî stack,whicè operateó likå CS® Anù codå 
routineó thaô uså A3-A· musô savå anä restorå them.

                              RUNNINÇ 6800° fig-FORTH

1® Loaä thå 6800° codå intï á 6800° systeí froí 2000-370Â oò aô whateveò placå yoõ 
chooså tï assemble.


2® Writå 6800° codå subroutineó foò EMIT,KEY,?TERMINAL.CR¬ anä R/× anä puô thå 
addresseó oæ theså subroutineó aô byteó 40-4¹ oî thå USEÒ pagå bù fillinç theí 
intï thå appropriatå locationó iî thå COLDUÓ datá block® Iô ió mucè easieò tï 
appenä thå customizeä codå tï thå 6800° sourcå anä assemblå thå wholå loô iî onå 
go® Thå addresseó oæ thå subroutineó wilì bå filleä iî automaticallù correct® 
Datá registeò D° ió useä tï pasó ASCIÉ byteó iî EMIÔ anä KEY,anä thå flaç iî 
?TERMINAL® Remembeò tï savå anä restorå addresó registeò A3-A· iæ theù arå used® 
FORTÈ wilì looë oî thå useò pagå foò thå addresseó oæ theså subroutines¬ anä COLÄ 
wilì havå puô theí there.

   3® Fiô U° S° R° TIÂ BKSPKEÙ BKSPEMIÔ DICTLIMIÔ FIRSÔ LIMIÔ USÅ 
PREÖ B/BUÆ  anä B/SCÒ tï fiô youò hardware® Dï thió bù changinç thå addresseó iî 
COLÄ aó needed® Iæ desired¬ oî thå firsô attempô tï brinç thió systeí up¬ 
WARNINÇ caî bå lefô 0® Buô iô musô bå resô tï ± iî ordeò foò thå disã wordó tï 
function.

   4® Ruî bù jumpinç tï thå labeì COLÄ (364Å iî thå unmodifieä case© oò lateò tï 
WARÍ (368A).
.PA

                        LAST MINUTE NOTES

   Sincå thå releaså oæ 1.° onå significanô buç haó beeî found® Thå +LOOĞ oæ 
versioî 1.° caî noô handlå negativå increments® Alsï iô waó founä thaô 1.° coulä 
noô fetcè datá froí odä addresses¬ buô iô coulä bå argueä thaô thió ió noô toï baä 
foò á 1¶ biô processor® Foò botè problemó Kennetè Manteé haó supplieä fixes¬ anä 
they are to be found in the appendix at page 58.
Botè fixeó arå fullù relocatable¬ sï yoõ maù uså thå heø codå directly as founä iî 
the assembly listing. No address translation is necessary.
   Iæ yoõ typå iî thå assemblù listinç foò yourselæ yoõ maù replacå thå sourcå oæ 
the listing for @ and (+LOOP) by the code given in the appendix.

To use the fix in an existing system type

HEX HERE 3053 , <other hex code > 4ED0 , 
' @  CFA !

and similar for (+LOOP), replace @ by (+LOOP).

Beforå yoõ coulä dï á colä starô witè thió patch¬ yoõ havå tï adjusô thå dictionary
start value in the bootup block, at address COLDUS+$0012

HEX HERE 368A !

Iô ió cleaneò tï storå HERÅ iî COLDUS+$001° (colä fence© aó well¬ buô nï harí caî 
bå donå aó iô ió noô possiblå tï forgeô orphaî codå withouô forgettinç thå 
preceeding word.

  Alsï includeä iî thå appendiø ió aî implementatioî oæ thå fig_FORTÈ MATCÈ worä 
thaô ió needeä foò thå strinç editinç wordó oæ thå EDITOÒ presenteä iî thå
fig-FORTÈ INSTALLATIOÎ MANUAÌ GLOSSARÙ MODEÌ RELEASÅ 1¬ MAÙ 1979® 
This was written by Kenneth Mantei to work with this fig-FORTH.

The MATCH word can also be "comma"ed in as usual:

CREATE MATCH 301B , < hex code > 4ED0 , SMUDGE ;S

The code of MATCH is relocatable as well.
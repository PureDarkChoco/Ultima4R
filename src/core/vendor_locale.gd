class_name VendorLocale
extends RefCounted

## Korean overlays for hardcoded VendorShop dialogue (xu4 vendors.b).
## English source line is the map key (with % placeholders still in the template).

static func is_korean() -> bool:
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null:
			return str(gs.language) == "ko"
	return false


static func _fill_places(text: String) -> String:
	if text.is_empty() or text.find("{") < 0:
		return text
	if Engine.get_main_loop() != null:
		var loc = Engine.get_main_loop().root.get_node_or_null("/root/Locale")
		if loc != null and loc.has_method("fill_places"):
			return str(loc.fill_places(text))
	return text


static func line(en: String) -> String:
	if en.is_empty() or not is_korean():
		return en
	if LINES.has(en):
		return _fill_places(str(LINES[en]))
	return en


static func specialty(en: String) -> String:
	if not is_korean():
		return en
	return str(SPECIALTY.get(en, en))


static func person_name(en: String) -> String:
	if not is_korean():
		return en
	return str(PERSON_NAMES.get(en, en))


static func weapon_desc(en_with_dollar: String) -> String:
	## `en_with_dollar` still uses `$` for price placeholder (pre-replace).
	if not is_korean():
		return en_with_dollar
	return str(WEAPON_DESC_KO.get(en_with_dollar, en_with_dollar))


static func armor_desc(en_with_dollar: String) -> String:
	if not is_korean():
		return en_with_dollar
	return str(ARMOR_DESC_KO.get(en_with_dollar, en_with_dollar))


static func heal_desc(en: String) -> String:
	if not is_korean():
		return en
	return str(HEAL_DESC.get(en, en))


## Tavern tip topic match: English name + Korean nouns.
static func topic_aliases(en_name: String) -> PackedStringArray:
	var out: PackedStringArray = [en_name.to_lower()]
	if TOPIC_ALIAS.has(en_name):
		for a in TOPIC_ALIAS[en_name]:
			out.append(str(a).to_lower())
	return out


static func topic_label(en_name: String) -> String:
	if is_korean() and TOPIC_ALIAS.has(en_name):
		var aliases: Variant = TOPIC_ALIAS[en_name]
		if typeof(aliases) == TYPE_ARRAY and not aliases.is_empty():
			return str(aliases[0])
	return en_name


static func rumor(en: String) -> String:
	if not is_korean():
		return en
	return _fill_places(str(RUMOR.get(en, en)))


const SPECIALTY := {
	"Lamb Chops": "양갈비",
	"Dragon Tartar": "드래곤 타르타르",
	"Brown Beans": "갈색 콩 요리",
	"Folley Filet": "폴리 필레",
	"Dog Meat Pie": "개고기 파이",
	"Green Granukit": "초록 그라누킷",
}

const PERSON_NAMES := {
	"Winston": "윈스턴",
	"Willard": "윌라드",
	"Peter": "피터",
	"Jumar": "주마르",
	"Hook": "후크",
	"Wendy": "웬디",
	"Valiant": "발리언트",
	"Jean": "진",
	"Pierre": "피에르",
	"Limpy": "림피",
	"Shaman": "샤먼",
	"Windrick": "윈드릭",
	"Donnar": "도나르",
	"Mintol": "민톨",
	"Max": "맥스",
	"Margot": "마고",
	"Sasha": "사샤",
	"Sheila": "실라",
	"Shannon": "섀넌",
	"Pendragon": "펜드래곤",
	"Harmony": "하모니",
	"Celest": "셀레스트",
	"Triplet": "트리플렛",
	"Justin": "저스틴",
	"Spiran": "스피란",
	"Starfire": "스타파이어",
	"Salle'": "살레",
	"Windwalker": "윈드워커",
	"Quat": "콰트",
	"Sam": "샘",
	"Celestial": "셀레스티얼",
	"Terran": "테란",
	"Greg 'n Rob": "그렉과 롭",
	"The Cap'n": "선장",
	"Arron": "애런",
	"Scatu": "스카투",
	"Jason": "제이슨",
	"Smirk": "스머크",
	"Estro": "에스트로",
	"Zajac": "자작",
	"Tyrone": "타이론",
	"Tymus": "타이머스",
	"Long John Leary": "롱 존 리어리",
	"One Eyed Willey": "외눈박이 윌리",
}

const HEAL_DESC := {
	"A curing": "해독",
	"A healing": "치유",
	"Resurrection": "부활",
}

const TOPIC_ALIAS := {
	"black stone": ["검은 돌", "black stone"],
	"sextant": ["육분의", "sextant"],
	"white stone": ["하얀 돌", "white stone"],
	"mandrake": ["맨드레이크", "mandrake"],
	"skull": ["해골", "skull"],
	"nightshade": ["밤그늘풀", "밤그늘", "나이트셰이드", "nightshade"],
}

const RUMOR := {
	"% says: Ah, the Black Stone. Yes I've heard of it. But, the only one who knows where it lies is the wizard Merlin.":
		"% 말하길: 아, 검은 돌 말인가. 들었지. 다만 그 소재를 아는 이는 마법사 멀린뿐이라네.",
	"% says: For navigation a Sextant is vital... Ask for item \"D\" in the Guild shops!":
		"% 말하길: 항해엔 육분의가 필수라네… 길드 상점에서 물건 \"D\"를 청해 보게!",
	"Now let me see... Yes it was the old Hermit... Sloven! He is tough to find, lives near Lock Lake I hear.":
		"어디 보자… 그래, 늙은 은둔자 슬로벤이지! 찾기 힘들고, 로크 호수 근처에 산다고 들었네.",
	"% says: The last person I knew that had any Mandrake was an old alchemist named Calumny.":
		"% 말하길: 맨드레이크를 가진 이를 마지막으로 본 건 늙은 연금술사 칼럼니였지.",
	"% says: If thou must know of that evilest of all things... find the beggar Jude. He is very very poor!":
		"% 말하길: 그 가장 사악한 것에 관해 알고 싶다면… 거지 주드를 찾게. 그는 몹시 가난하다네!",
	"% says: Of Nightshade I know but this... Seek out Virgil or thou shalt miss! Try in Trinsic!":
		"% 말하길: 밤그늘풀에 대해 내가 아는 건 이것뿐… 버질을 찾게, 놓치지 말게! {trinsic}에서 시험해 보게!",
}

const WEAPON_DESC_KO := {
	"We are the only staff makers in Britannia, yet sell them for only $gp.":
		"우리는 브리타니아에서 유일한 지팡이 장인이오. 그래도 $gp에 팔지.",
	"We sell the most deadly of daggers, a bargain at only $gp each.":
		"가장 치명적인 단검을 파오. 개당 $gp이면 거저나 다름없지.",
	"Our slings are made from only the finest guy and leather, 'Tis yours for $gp.":
		"우리 새총은 최상급 끈과 가죽으로 만들었소. $gp에 가져가시게.",
	"These maces have a hardened shaft and a 5lb head fairly priced at $gp.":
		"이 철퇴는 단단한 자루에 5파운드 머리가 달렸소. 정가 $gp.",
	"Notice the fine workmanship on this axe, you'll agree $gp is a good price.":
		"이 도끼의 정교한 세공을 보시오. $gp이면 썩 괜찮은 값일 거요.",
	"The fine work on these swords will be the dread of thy foes, for $gp.":
		"이 검의 솜씨는 적의 공포가 될 것이오. $gp.",
	"Our bows are made of finest yew, and the arrows willow, a steal at $gp.":
		"우리 활은 최상급 주목 나무, 화살은 버드나무. $gp에 훔쳐 가는 셈이지.",
	"Crossbows made by Iolo the Bard are the finest in the world, your for $gp.":
		"음유시인 이올로가 만든 석궁은 세상 최고. 당신 것이 $gp.",
	"Flasks of oil make great weapons and creates a wall of flame too. $gp each.":
		"기름병은 훌륭한 무기이자 불벽을 만들지. 개당 $gp.",
	"A Halberd is a mighty weapon to attack over obstacles; a must and only $gp.":
		"미늘창은 장애물 너머로 칠 수 있는 강력한 무기. 필수품이며 단 $gp.",
	"This magical axe can be thrown at thy enemy and will then return all for $gp.":
		"이 마법 도끼는 적에게 던져도 되돌아오오. 모두 $gp.",
	"Magical swords such as these are rare indeed I will part with one for $gp.":
		"이런 마법 검은 참으로 드물지. $gp이면 하나 내주겠소.",
	"A magical bow will keep thy enemies far away or dead! A must for $gp!":
		"마법 활이면 적을 멀리 두거나 쓰러뜨리오! $gp에 필수!",
	"This magic wand casts mighty blue bolts to strike down thy foes, $gp.":
		"이 마법봉은 푸른 광선으로 적을 내리치지. $gp.",
}

const ARMOR_DESC_KO := {
	"Cloth Armour is good for a tight budget, Fairly priced at $gp.":
		"천 갑옷은 예산이 빠듯할 때 좋소. 정가 $gp.",
	"Leather Armour is both supple and strong, and costs a mere $gp. A Bargain!":
		"가죽 갑옷은 유연하면서도 강하오. 고작 $gp. 특가!",
	"Chail Mail is the armour used by more warriors than all others. Ours costs $gp.":
		"사슬 갑옷은 기사들이 가장 많이 입는 갑옷. 우리 것은 $gp.",
	"Full Plate armour is the ultimate in non-magical armour. Get yours for $gp.":
		"풀 플레이트는 비마법 갑옷의 궁극. $gp에 가져가시게.",
	"Magic Armour is rare and expensive. This chain sells for $gp.":
		"마법 갑옷은 드물고 비싸오. 이 사슬은 $gp.",
	"Magic Plate Armour is the best known protection. Only we have it.  Cost: $gp.":
		"마법 플레이트는 알려진 최고의 방호. 우리만 있소. 가격: $gp.",
}

const LINES := {
	"I have nothing to sell thee.": "팔 것이 없소.",
	"Bye.": "안녕.",
	"Too bad. Maybe next time.": "아쉽군. 다음에.",
	"Closed.": "문을 닫았소.",
	"Welcome to\n%s\n\n%s says:\nWelcome friend!\nArt thou here to\nBuy (B) or Sell (S)?":
		"환영하오,\n%s\n\n%s 말하길:\n어서 오게, 벗이여!\n사겠소(B), 팔겠소(S)?",
	"%s says:\nArt thou here to\nBuy (B) or Sell (S)?":
		"%s 말하길:\n사겠소(B), 팔겠소(S)?",
	"Very Good!": "좋소!",
	"Excellent! Which\nwouldst ": "좋소! 무엇을 팔겠소?",
	"We Have:": "우리는 이런 것이 있소:",
	"Your Interest?": "관심사는?",
	"You have not the funds for even one!": "하나조차 살 돈이 없소!",
	"How many would\nyou like?": "몇 개 원하시오?",
	"Take it? (Y/N)": "가져가겠소? (Y/N)",
	"Too bad.": "아쉽군.",
	"I fear you have not the funds, perhaps something else.":
		"골드가 부족한 듯하오. 다른 것은 어떠시오?",
	"%s says: A fine choice!": "%s 말하길: 훌륭한 선택이오!",
	"Anything\nelse? (Y/N)": "더\n필요하시오? (Y/N)",
	"You sell:": "팔 것:",
	"Thou dost not own that. What else might":
		"그것은 갖고 있지 않소. 다른 것은?",
	"I will give you %dgp for that %s.\nDeal? (Y/N)":
		"%dgp에 그 %s를 사 들이겠소.\n거래하겠소? (Y/N)",
	"How many %ss\nwould you wish\nto sell?":
		"%s를 몇 개\n팔겠소?",
	"Hmmph. What else\nwould ": "흥. 다른 것은?",
	"You don't have that many swine!": "그렇게 많이 갖고 있지도 않소, 이 돼지 같으니!",
	"I will give you %dgp for them.\nDeal? (Y/N)":
		"그것들에 %dgp를 주겠소.\n거래하겠소? (Y/N)",
	"Fine! What else?": "좋소! 다른 것은?",
	"%s says:\nFare thee well!": "%s 말하길:\n잘 가게!",
	"Welcome to\n%s\n\n%s says:\nWelcome friend!\nWant to Buy (B) or\nSell (S)?":
		"환영하오,\n%s\n\n%s 말하길:\n어서 오게, 벗이여!\n사겠소(B), 팔겠소(S)?",
	"%s says:\nWant to Buy (B) or\nSell (S)?":
		"%s 말하길:\n사겠소(B),\n팔겠소(S)?",
	"Well then,": "그럼,",
	"What will": "무엇을 팔겠소?",
	"We've got:": "우리는 이런 것이 있소:",
	"What'll it be?": "무엇을 하겠어요?",
	"You don't have enough gold. Maybe something cheaper?":
		"골드가 부족하오. 더 싼 것은 어떠시오?",
	"%s says: Good choice!": "%s 말하길: 좋은 선택이오!",
	"Come on, you\ndon't own any.": "이보게,\n가진 게 없소.",
	"Harumph. What else would ": "흥. 다른 것은?",
	"%s says:\nGood Bye.": "%s 말하길:\n안녕히.",
	"Welcome to %s\n\n%s says: Good day, and Welcome friend.":
		"%s에 온 것을 환영하오\n\n%s 말하길: 좋은 날이오, 어서 오게 벗이여.",
	"Come back when you have some money!": "돈을 가지고 다시 오게!",
	"May I interest you in some rations? (Y/N)": "식량에 관심 있소? (Y/N)",
	"We have the best adventure rations, 25 for only %dgp.":
		"최고급 모험 식량이 있소. 25개에 단 %dgp.",
	"How many packs of 25 would you like?": "25개들이 팩을 몇 개 원하시오?",
	"You can only afford %d packs.": "살 수 있는 건 %d팩뿐이오.",
	"Thank you. ": "고맙소. ",
	"Come again!": "또 오시오!",
	"Goodbye. Come again!": "안녕히. 또 오시오!",
	"%s says: Welcome to %s": "%s 말하길: %s에 온 것을 환영하네",
	"%s says: What'll it be, Food (F) or Ale (A)?": "%s 말하길: 음식(F), 에일(A)?",
	"Our specialty is %s, which costs %dgp.": "특선은 %s이오. 값은 %dgp.",
	"How many plates would you\nlike?": "몇 접시\n원하오?",
	"%s says: Sorry, you seem to have too many. Bye!":
		"%s 말하길: 미안하군, 너무 많이 마신 듯해. 잘 가게!",
	"Here's a mug of our best.\nThat'll be 2gp.\nHow much will you pay?":
		"우리 최고 잔일세.\n2gp.\n얼마를 내시겠나?",
	"Ya can only afford %d plates.": "살 수 있는 건 %d접시뿐일세.",
	"Here ye arr.": "여기 있네.",
	"Somethin'\nelse? (Y/N)": "다른 것\n있나? (Y/N)",
	"Won't pay, eh.\nYa scum, be gone\nfore ey call the\nguards!":
		"안 낸다 이거지.\n이 쓰레기 같으니, 경비 부르기\n전에 썩 꺼져!",
	"It seems that you have not the gold. Good Day!":
		"골드가 없어 보이는군. 좋은 날 되시게!",
	"What'd ya like to know friend?": "뭘 알고 싶은가, 친구?",
	"'fraid I can't help ya there friend!": "미안하지만 그건 도와줄 수 없네, 친구!",
	"That subject is a bit foggy, perhaps more gold will refresh my memory. You\ngive:":
		"그 얘기는 좀 흐릿하군. 골드가 더 있으면 기억이 살아날지도. 자네가\n내는 액수:",
	"Ye don't have that mate!": "그 돈은 없구먼!",
	"Sorry, I could\nnot help ya mate!": "미안하지만\n도와줄 수 없네!",
	"See ya mate!": "잘 가게!",
	"A blind woman turns to you and says: Welcome to %s\n\nI am %s\nAre you in need of Reagents? (Y/N)":
		"눈먼 여인이 돌아보며 말합니다: %s에 오신 것을 환영합니다\n\n저는 %s입니다\n시약이 필요하신가요? (Y/N)",
	"Very well,": "좋습니다,",
	"I have": "있습니다",
	"Your\nInterest:": "관심사는:",
	"I have\nA-Sulfurous Ash\nB-Ginseng\nC-Garlic\nD-Spider Silk\nE-Blood Moss\nF-Black Pearl\nYour\nInterest:":
		"있습니다\nA-유황재\nB-인삼\nC-마늘\nD-거미줄\nE-피이끼\nF-흑진주\n관심사는:",
	"Very well, we sell %s for %dgp. How many would you\nlike?":
		"좋습니다. %s는 %dgp입니다. 몇 개\n원하십니까?",
	"Very good, that will be %dgp.  You pay:":
		"좋습니다. %dgp입니다.  내실 액수:",
	"It seems you have not the gold! ": "골드가 부족해 보이는군요! ",
	"Very good. ": "좋습니다. ",
	"I see, then ": "그렇군요, 그럼 ",
	"%s says:\nPerhaps another time then....\nand slowly turns away.":
		"%s 말하길:\n그럼 다음에....\n천천히 등을 돌립니다.",
	"Welcome unto\n%s\n\n%s says:\nPeace and Joy be with you friend.\nAre you in need of help? (Y/N)":
		"환영합니다,\n%s\n\n%s 말하길:\n평화와 기쁨이 함께 하기를, 벗이여.\n도움이 필요하시오? (Y/N)",
	"%s says: We can perform:\nA-Curing\nB-Healing\nC-Resurrection\nYour need:":
		"%s 말하길: 우리는 할 수 있소:\nA-해독\nB-치유\nC-부활\n필요한 것:",
	"%s asks:\nWho is in\nneed?":
		"%s가 묻소:\n누가\n필요하오?",
	"Thou suffers not from Poison!": "당신은 독에 걸린 것이 아니오!",
	"Thou art already quite healthy!": "벌써 아주 건강하오!",
	"Thou art not dead fool!": "죽지 않았소, 바보!",
	"%s will cost thee %dgp.": "%s는 %dgp요.",
	"I see by thy purse that thou hast not enough gold. I cannot aid thee.":
		"주머니를 보니 골드가 부족하오. 도울 수 없소.",
	"Wilt thou\npay? (Y/N)": "지불하겠소? (Y/N)",
	"%s asks: Do you need more help? (Y/N)": "%s가 묻소: 더 도움이 필요하시오? (Y/N)",
	"Art thou willing to give 100pts of thy blood to aid others? (Y/N)":
		"남을 돕기 위해 피 100을 주겠소? (Y/N)",
	"Thou art a great help. We are in dire need!":
		"큰 도움이 되시오. 우리는 절실히 필요하오!",
	"%s says: May thy life be guarded by the powers of good.":
		"%s 말하길: 선의 힘으로 삶이 지켜지기를.",
	"The Innkeeper says: Welcome to %s\n\nI am %s.\n\nAre you in need of lodging? (Y/N)":
		"여관 주인이 말합니다: %s에 오신 것을 환영합니다\n\n저는 %s입니다.\n\n숙박이 필요하신가요? (Y/N)",
	"The Innkeeper says: Get that horse out of here!!!":
		"여관 주인이 말합니다: 그 말은 당장 밖으로!!!",
	"%s says: Then you have come to the wrong place!\nGood day.":
		"%s 말하길: 그럼 이곳은 잘못 오셨소!\n좋은 날이오.",
	"We have three rooms available,\na 1, 2 and 3 bed room for 30, 60\nand 90gp each.\n1, 2 or 3\nbeds? (1/2/3)":
		"방이 셋 있소.\n1·2·3인 침대방, 각 30, 60,\n90gp.\n1, 2, 3\n침대? (1/2/3)",
	"We have a room with 2 beds that rents for 20gp.":
		"침대 두개짜리 방이 20gp요.",
	"Will you take the room? (Y/N)": "묵으시겠소? (Y/N)",
	"We have a modest sized room with 1 bed for 15 gp.":
		"보통 크기에 침대 하나, 15gp요.",
	"We have a very secure room of modest size and 1 bed for 10gp.":
		"보통 크기, 매우 안전한 방, 침대 하나 10gp요.",
	"We have a single bed room with a back door for 15gp.":
		"뒷문이 있는 1인실, 15gp요.",
	"Unfortunately, I have but only a very small room with 1 bed: worse yet, it's haunted! If you do wish to stay it costs 5gp.":
		"안타깝게도 작은 방 하나뿐이고 침대는 하나. 더구나 유령이 나오지! 그래도 묵겠다면 5gp요.",
	"All we have is that cot over there. But it is comfortable, and only 1 gp.":
		"저쪽 간이침대뿐이요. 그래도 편하고, 단 1gp.",
	"You won't find a better deal in this towne!":
		"이 마을에서 더 좋은 값은 없을 거요!",
	"If you can't pay, you can't stay! Good Bye.":
		"못 내면 묵을 수 없소! 안녕히.",
	"Very good.  Have\na pleasant night.":
		"좋습니다.  좋은\n밤 되시길.",
	"Oh, and don't mind the strange noises, it's only rats!":
		"아, 이상한 소리는 신경 쓰지 마시오. 쥐일 뿐이오!",
	"Avast ye mate! Shure ye wishes to buy from ol'\n%s?\n\n%s says: Welcome to %s.\nLike to see my goods? (Y/N)":
		"이봐 친구! 이 늙은\n%s에게서 사고 싶은가?\n\n%s 말하길: %s에 온 걸 환영하네.\n내 물건을 보겠나? (Y/N)",
	"%s says: Good Mate!\nYa see I gots:\nA-Torches\nB-Magic Gems\nC-Magic Keys\nWat'l it be?":
		"%s 말하길: 좋은 친구!\n내게 있네:\nA-횃불\nB-마법 보석\nC-마법 열쇠\n뭘로 하지?",
	"%s says: Good Mate!\nYa see I gots:":
		"%s 말하길: 좋은 친구!\n내게 있네:",
	"A-Torches": "A-횃불",
	"B-Magic Gems": "B-마법 보석",
	"C-Magic Keys": "C-마법 열쇠",
	"D-Sextant": "D-육분의",
	"Wat'l it be?": "뭘로 하지?",
	"I can give ya 5 long lasting Torches for a mere 50gp.":
		"오래가는 횃불 5개를 겨우 50gp에 주지.",
	"I've got magical mapping Gems, 5 for only 60gp.":
		"마법 지도 보석 5개가 60gp뿐.",
	"Magical Keys, 1 use each, a fair price at 60gp for 6.":
		"마법 열쇠, 각 1회용. 6개에 60gp, 공평한 값이지.",
	"So...Ya want a Sextant...Well I gots one which I might part with fer 900 gold!":
		"그래서… 육분의를 원하나… 내가 하나 갖고 있지. 900골드면 팔 수도 있지!",
	"Will ya buy? (Y/N)": "사겠나? (Y/N)",
	"Hmmm...Grmbl...": "흠… 으르릉…",
	"What? Can't pay! Buzz off swine!": "뭐? 못 내? 꺼져, 돼지 같으니!",
	"Fine... fine...": "좋아… 좋아…",
	"%s says: See\nmore? (Y/N)": "%s 말하길: 더\n보겠나? (Y/N)",
	"%s says: See ya matie!": "%s 말하길: 잘 가게, 선원!",
	"Welcome friend!\nCan I interest thee in\nhorses? (Y/N)":
		"어서 오게 벗이여!\n말에 관심 있소? (Y/N)",
	"A shame, thou looks like thou could use a good horse!":
		"아쉽군, 좋은 말이 필요해 보이는데!",
	"For only %dg.p.\nThou can have the best! Wilt thou buy? (Y/N)":
		"단 %dg.p.에\n최고를 가져갈 수 있소! 사겠소? (Y/N)",
	"It seems thou hast not gold enough to pay!":
		"지불할 골드가 부족한 듯하오!",
	"Here, a better breed thou shalt not find ever!":
		"여기 있소. 이보다 나은 혈통은 영원히 찾지 못할 것이오!",
}

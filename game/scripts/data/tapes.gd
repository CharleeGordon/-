class_name Tapes
extends RefCounted
## Audio logs (cassettes, wax cylinders, a voicemail). Voiced by tools/gen_voice.py.
## Each line: [speaker, text]. "fx" = recording effect. Audio: res://audio/voice/tape_<id>.ogg (+ timings json).

const LIST := [
	{"title": "Orientation Tape (1963)", "who": "Brenda Holloway", "fx": "tape", "lines": [
		["brenda", "Testing. Testing. Is this thing on? Lucy, stop pressing the buttons."],
		["brenda", "Hello, new night guard! This is Brenda Holloway, head of night security, and this is your orientation tape."],
		["brenda", "Rule one. The office is safe. Rule two. Walk, do not run, in the Egyptian Hall. The gentleman in the sarcophagus is a light sleeper."],
		["brenda", "And if the armour in the lobby moves, it did not. Write it in the log anyway. We have a whole drawer of those logs."],
		["brenda", "Lucy wants to say goodnight. Go on, sweetheart."],
		["brenda", "She's shy. Goodnight from both of us. Clock in, and have a lovely, quiet shift."],
	]},
	{"title": "Gift Shop Confession", "who": "Gary Finch", "fx": "tape", "lines": [
		["gary", "Okay. Gary here. Night nine. I need to confess something. I took a squeaky duck from the gift shop."],
		["gary", "I didn't pay. There's an honesty box. I am not, it turns out, an honest man."],
		["gary", "But listen. Throw one, and everything in this building goes to look at the squeak. Everything. The mummy. The clockwork kid. Even Gary. I mean me. Not me. You know what I mean."],
		["gary", "So. Squeak, then run the other way. That's the whole strategy. That's all I've got. Please put a coin in the box for me."],
	]},
	{"title": "Wax Cylinder No. 1 (1928)", "who": "Sir Archibald Pemberton", "fx": "phonograph", "lines": [
		["pemberton", "Recorded on the fourteenth of March, nineteen twenty eight. Sir Archibald Pemberton, speaking."],
		["pemberton", "Today I have acquired the finest object in any collection on God's green earth. The Golden Duck of Ur-Quack."],
		["pemberton", "The dealer would not take my money. He simply ran. I have never seen a grown man run so fast."],
		["pemberton", "No matter. The Duck shall have the place of honour in the Great Hall. I feel, already, that it is very pleased with me."],
	]},
	{"title": "Voicemail, Mum's Old Number", "who": "Lucy Holloway", "fx": "voicemail", "lines": [
		["lucy", "Hi, Mum. It's me again. I know this number doesn't work anymore. I just like the beep."],
		["lucy", "I hired a new guard today. The forty first. He clocked in, and I heard your voice on the security channel. Telling him the rules. Your rules."],
		["lucy", "I don't know if you can hear me. I don't know what you are now. But I'm still at the window, Mum. I'm still waiting."],
		["lucy", "Okay. Okay. Goodnight."],
	]},
	{"title": "Night Thirty", "who": "Gary Finch", "fx": "tape_tremble", "lines": [
		["gary", "Night thirty. I can't feel my fingers. They're not cold. They're... smooth."],
		["gary", "My reflection in the costume room mirror didn't blink when I did. It was a second late. Then two seconds."],
		["gary", "I tried to go home this morning. I walked to the front door. Then I turned left and did the patrol route again. I didn't decide to. My feet did."],
		["gary", "If anybody finds this. My name is Gary Finch. I was a night guard. I think I still am. I think I always will be."],
	]},
	{"title": "Report: The Armour", "who": "Brenda Holloway", "fx": "tape", "lines": [
		["brenda", "Security report, October nineteen sixty three. At two oh five, Sir Clanksworth left his rope area and was found in the Armoury."],
		["brenda", "Standing very close to the Duchess's portrait. Which had been moved. Into the Armoury."],
		["brenda", "I am not paid enough to investigate a romance. I have returned them both to their places. Again."],
		["brenda", "Note to self. Buy Lucy the yellow raincoat on Saturday. She keeps asking."],
	]},
	{"title": "Wax Cylinder No. 4 (1931)", "who": "Sir Archibald Pemberton", "fx": "phonograph", "lines": [
		["pemberton", "October, nineteen thirty one. I am afraid. I am recording this so that someone will know."],
		["pemberton", "Tonight the Duck quacked my name. Archibald. Very softly. Like a man calling his dog."],
		["pemberton", "Every exhibit in this building walked to the Great Hall and stood around it in a circle. Facing it. Waiting."],
		["pemberton", "I know what must be done. The altar. The fire. But it looked at me, and I wanted so very much to make it happy."],
	]},
	{"title": "Last Tape (1963)", "who": "Brenda Holloway", "fx": "tape_tremble", "lines": [
		["brenda", "This is Brenda. It's the eleventh of November. I don't have long. My hands have gone stiff. I can barely press record."],
		["brenda", "Something in the basement. The founder. He's still down there. He said I belong to the collection now."],
		["brenda", "Lucy. Sweetheart. If anyone ever plays you this tape. Mummy is working late tonight."],
		["brenda", "Mummy might be working late for a very long time. Be good for Grandma. Wear your yellow raincoat."],
		["brenda", "I love you. I love you. I'm going to keep the new guards safe for you. I promise. I'll keep everyone safe."],
	]},
	{"title": "Advice for the Next Guy", "who": "Gary Finch", "fx": "tape", "lines": [
		["gary", "Hey. Next guy. It's Gary. Some advice, from a man who is now about forty percent candle."],
		["gary", "One. Wind the kid. Two. Don't run in Egypt. Three. When the paintings whisper, freeze like you're in a school photo."],
		["gary", "Four. If you see me, I'm sorry. Hide. I have a flashlight and a very strong sense of duty and absolutely no brain left."],
		["gary", "Five. Brenda's the best boss I ever had. Do what she says. She's been doing this a lot longer than anyone knows."],
	]},
	{"title": "Wax Cylinder No. 7 (1931)", "who": "Sir Archibald Pemberton", "fx": "phonograph", "lines": [
		["pemberton", "I have decided. I shall not melt it. I shall guard it. Forever, if I must."],
		["pemberton", "My skin is becoming beautifully smooth. Like a fine exhibit. I shall be the finest exhibit of all."],
		["pemberton", "Whoever comes for my Duck. Whoever you are, listening to this, years from now."],
		["pemberton", "I will be waiting for you in the dark. And I will add you to my collection."],
	]},
	{"title": "The Tea Party", "who": "Unknown", "fx": "phonograph", "lines": [
		["dolls", "One for you, and one for me, and one for the guard who came to tea."],
		["dolls", "Sit down, sit down, the tea is hot. Look away, look away, and we will not. Hee hee."],
		["dolls", "There is always one more cup. There is always one more cup."],
	]},
	{"title": "For the New Guard", "who": "Lucy Holloway", "fx": "voicemail", "lines": [
		["lucy", "Hello. You don't know me. I'm the Director. I'm the one who hired you."],
		["lucy", "If you've found this, then you've heard her. On the radio. Brenda. She was my mother."],
		["lucy", "I've hired forty guards hoping one of them would get to the vault. None of them were brave enough. Or daft enough."],
		["lucy", "Please. Bring her home. Let her clock out. And then, if you like, you can have my job. It's terrible. You'll love it."],
	]},
]


static func title(id: int) -> String:
	return LIST[id - 1]["title"]


static func who(id: int) -> String:
	return LIST[id - 1]["who"]

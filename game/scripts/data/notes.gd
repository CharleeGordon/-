class_name Notes
extends RefCounted
## Lore documents found around the museum. Index = note id (1-based in game).

const LIST := [
	{
		"title": "Memo: Welcome Aboard",
		"text": "TO: New Night Guard\nFROM: Brenda Holloway, Head of Night Security\n\nWelcome to the Pemberton Museum of Questionable History!\n\nYour predecessor, Gary, left us suddenly last month. No forwarding address. His coffee mug is still in the office. Please do not use it. It is evidence.\n\nThe rules on the poster are not jokes. I know they look like jokes. They were written by someone with a sense of humour, which is how you know they are serious.\n\nI will be on the radio all night. I am always on the radio.\n\n- B.H.",
	},
	{
		"title": "Pemberton's Diary, p. 1",
		"text": "14th March, 1928.\n\nAcquired today, at no small expense, the Golden Duck of Ur-Quack. The dealer wept with relief as I carried it out. Odd fellow.\n\nThe Duck is magnificent. Its eyes follow you about the room. I assume this is a trick of the light. The light in this room is very poor.\n\nPlaced it in the Great Hall. Tomorrow I shall build it a pedestal worthy of its station.",
	},
	{
		"title": "Gary's Patrol Notes #1",
		"text": "Week 1.\n\nThe armour in the lobby moved again. Brenda says this is 'normal'. Brenda says a lot of things are normal.\n\nTip for the next guy (if there is one): don't blink near Sir Clanksworth. I mean it. Keep your flashlight charged.\n\nAlso the vending machine eats quarters. That one is not supernatural, it's just broken.",
	},
	{
		"title": "Pemberton's Diary, p. 2",
		"text": "2nd June, 1928.\n\nThe clockwork boy - I have named him Wolfgang - played his little tune all night without being wound. When I came down in the morning he was facing the door.\n\nThe Egyptian gentleman's bandages have been rewrapped. Neatly. By whom?\n\nThe Duck sat on its pedestal looking extremely pleased with itself.",
	},
	{
		"title": "Gary's Patrol Notes #2",
		"text": "Week 3.\n\nWOLFGANG. KEEP HIM WOUND. When the music slows down you have about thirty seconds. When the music STOPS you are already in trouble.\n\nHe's small but he's fast and he can hear you breathing. Get in a locker. Hold your breath. Think about something nice.\n\nI thought about pancakes. It worked.",
	},
	{
		"title": "Newspaper Clipping, 1963",
		"text": "THE PEMBERTON GAZETTE - 12 November 1963\n\nNIGHT WATCHWOMAN VANISHES FROM LOCAL MUSEUM\n\nMrs. Brenda Holloway (41), head of night security at the Pemberton Museum, failed to return home after her shift on Tuesday. Her radio was found switched on.\n\nThe museum's curator stated that 'nothing is missing, apart from Mrs. Holloway, and possibly a spoon.'\n\nThe museum will open as usual on Thursday. A new wax figure is planned for the east wing.",
	},
	{
		"title": "Letter from the Duchess, 1788",
		"text": "My dearest Sister,\n\nThe painter Mr. Hobbs has finished my portrait. He says I look 'disappointed'. I told him I was not disappointed until I saw the portrait.\n\nI shall be watching over the house from the drawing-room wall for many years to come. Tell the servants that if they wish to idle, they had better do it standing very, very still.\n\nYour sister, D.",
	},
	{
		"title": "Gary's Patrol Notes #3",
		"text": "Week 5.\n\nThe paintings watch you during storms. You'll hear whispering first. Then you STOP. Don't run, don't walk, don't scratch your nose.\n\nI've started to feel stiff after my shifts. Like I'm made of something. My skin looks... shiny?\n\nBrenda says it's the air conditioning.",
	},
	{
		"title": "Pemberton's Diary, p. 3",
		"text": "31st October, 1931.\n\nI understand it now. The Duck does not merely sit in the museum. The Duck OWNS the museum, and everything in it. Every exhibit it owns, it wakes.\n\nAnd anyone who stays too long among its things becomes one of its things.\n\nThere is only one remedy. In the vault beneath the Egyptian Hall is the altar where it was first awakened. Melt it there and it sleeps forever. I could not bring myself to do it. It looked at me.\n\nI have locked the vault. God help whoever finds the key.",
	},
	{
		"title": "Gary's Last Note",
		"text": "If you're reading this, you found my locker. Sorry about the smell. That's the wax.\n\nI can't leave anymore. I tried. My feet just walk the patrol route. I still do my rounds, every night. It's the only thing that feels normal.\n\nIf you see me - and you will - DON'T let me see you. I won't mean it. But I'll still do it.\n\nThe vault keycard is in here. Brenda knows what it's for. Ask her what happened in 1963.\n\n- Gary (Night Guard, still technically employed)",
	},
	{
		"title": "Wax Hall Restoration Log",
		"text": "WAX HALL - RESTORATION LOG\n\nFigure #1: Napoleon's Neighbour - nose reattached.\nFigure #2: A Pirate (Allegedly) - hat found in the Egyptian Hall. Again.\nFigure #3: Inventor of the Spoon - fine.\nFigure #4: Brenda Holloway - figure is warm to the touch. Radio in hand will not switch off. Do not attempt to remove radio.\nFigure #5: (pending) - Night Guard, G. Finch. Not yet installed. Appears to install himself.",
	},
	{
		"title": "Brenda's Note (Unsent)",
		"text": "New guy,\n\nIf you've come this far, you deserve the truth. I've been on this radio for sixty years. I can't remember the last time I went home. I can't remember home.\n\nThe Duck keeps us. All of us. Gary. The knight. The Duchess. Me.\n\nTake it to the altar. Melt it. When it sleeps, we sleep. And that's alright. It's been a very long shift.\n\nThank you for clocking in.\n\n- B.",
	},
]


static func title(id: int) -> String:
	return LIST[id - 1]["title"]


static func text(id: int) -> String:
	return LIST[id - 1]["text"]

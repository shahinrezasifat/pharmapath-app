#!/usr/bin/env python3
"""Author condition quick guides into the learning library, then re-validate it.

The catalogue itself lives in the assets:

  * assets/learning/library_<track>.json   - condition courses, one file per shelf
  * assets/learning/body_systems_atlas.json- organ, region and condition groups
  * assets/learning/library_tracks.json    - shelf ids and their Bangla labels

New guides are written as compact specs below. The tool merges them into the
shipped shelves, re-links every atlas row from the tags the courses carry, and
refuses to write unless each course (old and new) passes the app's content rules
and every atlas row has at least one lesson to open.

Run from the project root:

    python3 tool/build_learning_expansion.py
"""

import glob
import json
import os
import re
import sys

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'learning'
)

TRACKS = [
    ('daily', 'দৈনন্দিন অস্বস্তি ও সাধারণ যত্ন'),
    ('infection', 'সংক্রমণ, জ্বর ও পরজীবী'),
    ('heart', 'হৃদয়, রক্তচাপ ও রক্তনালী'),
    ('lungs', 'শ্বাসনালী, ফুসফুস ও দূষণ'),
    ('gut', 'পেট, অন্ত্র, লিভার ও গুদদ্বার'),
    ('kidney', 'কিডনি, মূত্রতন্ত্র ও প্রোস্টেট'),
    ('hormone', 'হরমোন, থাইরয়েড ও বিপাক'),
    ('nerve', 'মস্তিষ্ক, স্নায়ু ও মেরুদণ্ড'),
    ('mental', 'মানসিক স্বাস্থ্য, দুশ্চিন্তা ও ঘুম'),
    ('eye', 'চোখ ও দৃষ্টি'),
    ('ent', 'কান, নাক ও গলা'),
    ('mouth', 'মুখ, দাঁত ও মাড়ি'),
    ('skin', 'ত্বক, চুল ও নখ'),
    ('bone', 'হাড়, জয়েন্ট ও পেশি'),
    ('blood', 'রক্ত, অ্যালার্জি ও রোগপ্রতিরোধ'),
    ('women', 'নারী স্বাস্থ্য ও গর্ভাবস্থা'),
    ('child', 'শিশু ও কিশোর স্বাস্থ্য'),
    ('elderly', 'প্রবীণ বয়স ও দীর্ঘমেয়াদি যত্ন'),
    ('emergency', 'আঘাত, পোড়া ও জরুরি চিকিৎসা'),
    ('environment', 'পরিবেশ, পেশা, ভ্রমণ ও বিষক্রিয়া'),
    ('medicine', 'ঔষধ জ্ঞান ও নিরাপদ ব্যবহার'),
    ('practice', 'ফার্মেসি ও ক্লিনিকাল অনুশীলন'),
]

ATLAS_GROUPS = [
    ('core', 'মূল অঙ্গতন্ত্র'),
    ('organ', 'অঙ্গ-প্রত্যঙ্গভেদে'),
    ('region', 'শারীরিক অঞ্চল'),
    ('life', 'জীবনচক্র ও বিশেষায়িত যত্ন'),
    ('group', 'রোগের শ্রেণি'),
]


def ul(items):
    return ''.join('<li>%s</li>' % i for i in items)


def sec(title, items):
    return '<h3>%s</h3><ul>%s</ul>' % (title, ul(items))


def Q(question, options, answer, explanation):
    return {
        'question': question,
        'options': list(options),
        'answer': answer,
        'explanation': explanation,
    }


def lesson(cid, index, title, summary, minutes, sections, keys, quiz):
    body = '<p><strong>সংক্ষেপে:</strong> %s</p>' % summary
    for head, items in sections:
        body += sec(head, items)
    return {
        'id': '%s-%d' % (cid, index),
        'title': title,
        'summary': summary,
        'minutes': minutes,
        'body': body,
        'keyPoints': keys,
        'quiz': quiz,
    }


NEW_COURSES = []


def g(cid, title, subtitle, icon, track, sysid, **f):
    """One-lesson quick guide: recognise, care, and the red-flag line in a single
    sitting, with a lesson quiz plus a fresh course-final scenario."""
    l1 = lesson(
        cid, 1, f['l1t'], f['intro'], f.get('m', 8),
        [
            ('শরীরে আসলে কী ঘটে', f['cause']),
            ('যেভাবে চিনবেন', f['sym']),
            ('কী করবেন ও চিকিৎসায় কী হয়', f['care']),
            ('জরুরি সংকেত—দেরি করবেন না', f['red']),
        ],
        [f['cause'][0], f['sym'][0], f['red'][0]],
        f['q'],
    )
    NEW_COURSES.append({
        'id': cid,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'category': 'body',
        'track': track,
        'body_system_id': sysid,
        'atlas_tags': list(f.get('tags') or []),
        'difficulty': f.get('difficulty', 'Beginner'),
        'estimated_duration': l1['minutes'],
        'lessons': [l1],
        'quiz': [f['q'][1], f['final']],
    })


# ---------------------------------------------------------------------------
# Newly authored quick guides
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# জরুরি যত্ন, শয্যাগত রোগী ও ল্যাব-অনুশীলন
# ---------------------------------------------------------------------------

g('burns-scalds', 'পোড়া-ছুঁটা ও জরুরি প্রাথমিক যত্ন', 'ঠান্ডা-পানি ২০ মিনিট—কতখানি গভীর, কখন হাসপাতাল', 'emergency', 'emergency', 'emergency_first_aid',
  tags=['injury-first-aid', 'skin-appendages'],
  l1t='পোড়া মাপা ও থামানো', intro='পোড়া-আঘাতে প্রথম ২০ মিনিটের ঠান্ডা-পানিই ক্ষতির গভীরতা কমায়; টুথপেস্ট-মাখান-ময়দা সব-ই বিপদ-বাড়ায়।',
  cause=['তাপ-পানি-ভাত-তেল (ঘরে-শিশুতে-প্রধান), খোলা-আগুন-ইসতি-চুলা, রাসায়নিক (লবণ-গাঁজ-পাইপ-পরিষ্কারকারক), বিদ্যুৎ-তড়িৎ-ধাক্কা, সূর্য-তাপ।', 'গভীরতা: লাল-চুলকানি (সূর্য), ফোসকা-তীব্র-ব্যথা (আংশিক-পুরু), শাদা-চামড়া-কম-ব্যথা-গোম (পূর্ণ-পুরু), কালো-কাঠ-জাত (গভীর-তন্তু)।', 'আয়তন: হাতের-তালু-১ শতাংশ; ১০ শতাংশের-বেশি-গুরুতর-শিশুতে-৫ শতাংশেই বিপদ।', 'জটিলতা: নির্জলতা-শ্বাস (মুখ-নাক-চুল-পোড়া)-সংক্রমণ-তিন-সপ্তাহে-না-সামলে-স্কার।'],
  sym=['লাল-গরম-চুলকানি ২-৩ দিনে-খসখসে-কমে—হালকা।', 'ফোসকা-ভেতরে-জল-তীব্র-ব্যথা-২ সপ্তাহে-সারে—আংশিক; ফোসকা-ফাটলে-পুঁজ-গন্ধ-জ্বর-সংক্রমণ।', 'শাদা-খড়-জাত-অবস্থা-স্পর্শে-কম-ব্যথা—গভীর, অস্ত্রোপচার-চামড়া-ট্রান্সপ্লান্ট-লাগে।', 'রাসায়নিক-পোড়া: ধুয়ে-ফেললে-ও ব্যথা-থাকে, ত্বক-কালো-শাদা; বিদ্যুতে-বুক-ধকধক-অসাড়মর-হাত-পা-পোড়া-দুই-বিন্দু।'],
  care=['ঠান্ডা-চলন্ত-পানিতে ২০ মিনিট (বরফ-নয়)-কাপড়-খুলে ফেলুন-আটকানো-গহনা-ঘড়ি-আঙ্গুরিয়াল।', 'পরিষ্কার-প্লাস্টিক-র‍্যাপ-ঢাকা (আটকানো-নয়)-জীবাণু-নাশক-ক্রিম-নিজ-ইচ্ছায় নয়; ফোসকা-ফাটাবেন না।', 'ব্যথায় প্যারাসিটামল; বড়-পোড়ায়-ওরশ্যালাইন-পানি-বহু-তরল; জ্বরের-পূর্বেই-টিকা (টেনেটাস)-পরীক্ষা।', 'চিকিৎসায়: সিলভার-সালফাডায়াজিন-জাত ড্রেসিং-এক্সসিজশন-চামড়া-গ্রাফট-আইসিইউ; শ্বাস-পোড়ায়-অক্সিজেন-নালী-পরীক্ষা।'],
  red=['হাত-পা-মুখ-চোখ-যৌনাঙ্গ-গাঁট-জড়ে পোড়া (২ সপ্তাহে-স্কার)-আজই বিশেষজ্ঞ।', '৫ শতাংশের-বেশি শিশু, ১০ শতাংশের-বেশি প্রাপ্তবয়স্ক, ৬০+ বা গর্ভবতী।', 'মুখ-নাক-পোড়া-স্বরে-বসে-গলা-ফোলা-শ্বাস-কষ্ট (বাতাস-নালী-ক্ষতি)।', 'রাসায়নিক-চোখে, বিদ্যুৎ-আঘাত, বৈদ্যুতিক-হৃদ-অনিয়ম, পোড়ার-পরে-জ্বর-দুর্গন্ধ-লাল-রেখা।'],
  q=[Q('পোড়ে প্রথম ২০ মিনিটে সবচেয়ে উপকারী কাজ?', ['টুথপেস্ট-মাখানো', 'ঠান্ডা-চলন্ত-পানি-সেক', 'বরফ-সরাসরি-চাপ'], 1, 'প্রবাহ-মান-তাপ-থামায়-ব্যথা-কমায়; টুথপেস্ট-সংক্রমণ, বরফ-অতিরিক্ত-ক্ষতি করে।'),
     Q('কোন পোড়া হাসপাতাল-আবশ্যক?', ['হাতের-তালুর-কম-লাল-দাগ', 'মুখ-নাক-পোড়া-স্বরে-বসে-যাওয়া', 'আঙুলের-ফোসকা'], 1, 'শ্বাস-নালীর-স্ফীতি ২৪ ঘণ্টায়-বাড়ে; পূর্ব-প্রস্তুতি-না-নিলে বিপদ।')],
  final=Q('৩ বছরের শিশু গরম-চায়ের জগ-উল্টে-গলা-বুকে ফোসকা, আয়তন-হাতের-তালুর-৮ গুণ। করণীয়?', ['ঘরে-ক্রিম-ড্রেসিং', 'তাত্ক্ষণিক-পানি-সেক-ওরশ্যালাইন-পরে-পোড়া-বিভাগে', 'তেল-মাখিয়ে-রাখা'], 1, 'শিশুতে আয়তন-গুরুত্ব-আলাদা-স্কেল; তরল-হ্রাস-দ্রুত-নির্জল-করে-বিশেষজ্ঞ-ভর্তি।'))

g('bleeding-wounds', 'রক্ত-ক্ষত, কেটে-ছেঁড়া ও টেনে-আসা', 'চাপ-উঁচু-ড্রেসিং-টেনে-আসা-জখম-কখন থেমে-না-থাকলে জরুরি', 'emergency', 'emergency', 'emergency_first_aid',
  tags=['injury-first-aid'],
  l1t='রক্ত থামানোর নিয়ম', intro='অধিকাংশ ক্ষত ১০ মিনিট স্থির চাপে থেমে যায়; বারবার তুলো সরিয়ে দেখা জমাট ভেঙে দেয়—আঙুলের চাপই প্রধান।',
  cause=['কেটে-ছেঁড়া (তীক্ষ্র), ঘষে-চামড়া-উঠে-গেলে, ছেঁড়া-গাঁট-হাড় (মার-খাওয়া), বিঁধে-গেলে (কঁটা-পেরেক)।', 'রক্ত-পাতলা ঔষধ (ওয়ারফারিন-ক্লোপিডোগ্রেল-এনএসএআইডি)-লিভার-রোগ-রক্ত-প্লেটলেট-কম-থাকলে-দীর্ঘ-ক্ষত।', 'ধমনী-রক্ত: উজ্জ্বল-লাল-স্পন্দনে-গড়ানো—কয়েক-মিনিটে প্রাণ-যায়; শিরায়-ধীর-গাঢ়।', 'ফুঁটা-ভেতরে-রক্ত-জমা-ফোলা-ত্বকে-কালো-দাগ (হেম্যাটোমা)-মাথায়-বুক-পেটে-গভীর-রক্ত-ক্ষতি।'],
  sym=['ক্ষত-চিহ্ন: পরিষ্কার-কেটে-ধারা-থামানো-যায়; অস্বাভাবিক-ধার-ফুটো-জায়গা-ভেতরে-কিছু-আটকা—ছেদন-সলাই।', 'হাত-পা-উঁচু-করলে-রক্ত-কমে; নাড়ি-দ্রুত-চাপ-পতন-ত্বক-ঠান্ডা-২ লিটার-ক্ষতির ইঙ্গিত।', 'গভীর বুকে-পেটে-ক্ষত-শ্বাসকষ্ট-তন্দ্রা-পেটে-কঠিন-ভাব—অভ্যন্তরীণ-রক্ত-গড়ানো।', 'মাথায়-আঘাত-রক্ত-বমি-ঘাড়-শক্ত-অসাড়মর-আচরণ-পরিবর্তন (জরুরি)।'],
  care=['স্থির-চাপ: পরিষ্কার-কাপড়-১০ মিনিট-না-উঠিয়ে-আঙুলে-চাপ; রক্ত-সেঁকে-নতুন-ড্রেসিং-উপরে (নিচের-জমাট-না-ছাড়বেন)।', 'উঁচু করে রাখুন-গহনা-ঘড়ি-খুলুন-অ্যাড্রেনালিন-জাত-স্প্রে-নিজ-ইচ্ছায় নয়; ধোয়া-কেবল-পরিষ্কার-জলে-গভীর-ক্ষতে-অ্যাণ্টিসেপটিক-চিকিৎসক।', 'ছোট-ক্ষত: বন্ধ-ধুলো-জীবাণুহীন-মলম-প্লাস্টার-১-২ দিন-বদল; টেনে-আসা-জখম-টেনে-দেখা-কাঁটা-না-টানুন।', 'চিকিৎসায়: সলাই-স্ট্যাপল-স্ট্রিপস (১২-২৪ ঘণ্টার-ভিতরে), টেনে-আসা-ট্যাটু-ক্ষতে-পেরেক-টিকে-থাকা-ক্ষতে টেনে-আসা-টেনে-আসা-নিয়ম, টেনে-আসা-টেনে-আসা-জখম।'],
  red=['চাপে-১৫ মিনিটে-না-থেমে, অথবা ২৪ ঘণ্টায়-ব-বার-ফের-রক্ত-ক্ষত।', 'উজ্জ্বল-লাল-স্পন্দিত-ধারা, ক্ষত-গভীরে-হাড়-দেখা, অঙ্গ-বিকৃত।', 'রক্ত-পাতলা ঔষধ-খাওয়া-কোনো-আঘাতে-দীর্ঘ-রক্ত-মাথায়-আঘাত (আশঙ্কাজনক)।', 'ক্ষত-লাল-গরম-পুঁজ-লাল-রেখা-জ্বর (সংক্রমণ), টেনে-আসা-জখম-টেনে-আসা-জখমের টেনে-আসা-কম্পন-চোখ-মুখ-আটকা।'],
  q=[Q('ক্ষত-রক্তে ঘরে প্রথম-কাজ কোনটি?', ['৫ বার-উঠিয়ে দেখা', '১০ মিনিট স্থির-চাপ-উঁচু-রাখা', 'গরম-পানি-ধোয়া'], 1, 'জমাট-ভাঙা-হলে-আবার-রক্ত; না-উঠিয়ে-চাপ-ই-৯০ শতাংশ-ক্ষতে-যথেষ্ট।'),
     Q('টেনে-আসা-জখম-কেন-নিজে নাড়াচাড়া করা যায় না?', ['সংক্রমণ', 'রক্ত-গড়ানো-বাড়ে-আঘাত-অস্থি-স্নায়ু-ক্ষতি', 'ব্যথা'], 1, 'স্থিতি-টানা-বন্ধ-থাকে; ছেদন-নমুনা-করলে অসাড়মর-সংক্রমণ-বাড়ে।')],
  final=Q('৭৮ বছরের-ওয়ারফারিন-খাওয়া-রোগী হাতে-কাটা-২০ মিনিট-রক্ত-থামছে না। করণীয়?', ['প্লাস্টার-বাঁধা', 'জরুরি বিভাগ—চাপ-ড্রেসিং-ও INR-তদন্ত', 'মাথায়-গুঁড়া-লাগানো'], 1, 'অ্যান্টিকোয়াগুলেন্ট-নিয়ন্ত্রণ-হীন-ক্ষত-বিপদ; হাসপাতাল-পরিবর্ধন-পরীক্ষা-পরিবর্তন-দরকার।'))

g('bedridden-care', 'শয্যাগত রোগীর ঘরের যত্ন', 'চাপ-ক্ষত, নিউমোনিয়া, প্রস্রাব-আহার—পরিবারের-দৈনন্দিন চেকলিস্ট', 'elderly', 'elderly', 'musculoskeletal',
  tags=['disability-rehab'],
  l1t='দীর্ঘ-শোয়ার চার বিপদ', intro='টানা-বিছানায়-৪-সিটেমে আঘাত পায়—ত্বক, ফুসফুস, মূত্রতন্ত্র, গাত্ৰ-পেশি; প্রতি-২ ঘণ্টার-পরিবর্তন-ই-চিকিৎসা।',
  cause=['চাপ-ক্ষত (প্রেসার আলসার): কুচি-গোপন-হিল-কোহনী-জরুরি-স্থানে-রক্ত-চলা-আটকায়-ত্বক-নেক্রোসিস।', 'অবস্ট্রাকটিভ নিউমোনিয়া-শ্বাস-নিঃশ্বাসে-কফ-জমে-শ্বাসকষ্ট-জ্বর।', 'মূত্র-আটকা-ক্যাথেটার-নিয়মিত-সংক্রমণ-কিডনি-ক্ষতি; কোষ্ঠকাঠিন্য-আহার-কম-অ্যাক্টিভিটি।', 'পেশি-গলানো-জমে-গাঁট (কন্ট্র্যাকচার)-গভীর-শিরায়-জমাট-রক্ত (ডিভিটি)-মানসিক-বিভ্রম।'],
  sym=['ত্বকে-দাগ-লাল-জায়গা-চাপ-দিলে-সাদা-না-হওয়া-ক্ষত-দুর্গন্ধ-গহ্বর—স্টেজ-২-৪।', 'জ্বর-খশখশ-শ্বাস-কফ-রং-পরিবর্তন-অক্সিজেন-কম-তন্দ্রা।', 'প্রস্রাব-কম-গন্ধ-জ্বলা-জ্বর-পেটে-আটকা; পায়খানা-৩ দিন-না-হওয়া-ফেঁপে-ব্যথা।', 'গাঁট-শক্ত-ভাঁজ-নড়াচড়া-কম-কাপড়-পরাতে-ব্যথা-হাত-পা-ফোলা।'],
  care=['প্রতি-২ ঘণ্টায়-পাশ-পরিবর্তন-৩০ ডিগ্রি-বাঁ-ডান-পিঠ; হিল-কুচিতে-ফোম-ওড়ানা-খাট-ম্যাত্রেস-উঁচু-তাকিয়া-কাঁধ-গোপনে।', 'গভীর-শ্বাস-দিনে-৫ বার-১০ বার-হাঁপ-গুঁটি-বলুন; বুকে-হালকা-চাপড়ে-কফ-নিকাশে-সহায়তা; ঘাম-কাপড়-বদল।', 'মূত্র-ক্যাথেটার-নিয়ম: থলে-নিচু-সংযোগ-পরিষ্কার-সপ্তাহে-১ বার-পরিবর্তন; টানা-অ্যান্টিবায়োটিক নয়-লক্ষণ-থাকলে-পরীক্ষা।', 'আহার-প্রোটিন-ডিম-মাছ-ডাল-পনির-দই, দিনে ৬-৮ গ্লাস তরল (ডায়ালাইসিসে-মাপ-অনুযায়ী), নিয়মিত-আঁশা; ৩ দিন-না-হলে ডাক্তার।'],
  red=['ত্বকে-দুর্গন্ধ-গহ্বর-কালো-মৃত-টিস্যু-জ্বর (গভীর-ক্ষত-অস্ত্রোপচার-ড্রেসিং)।', 'হঠাৎ-শ্বাসকষ্ট-বুক-ব্যথা-এক-পা-ফোলা-গরম (ডিভিটি-পেপটিক-অ embolism)।', 'তন্দ্রা-অস্পষ্ট-জ্বর-ঠান্ডা-শরীর-প্রস্রাব-কম (সেপসিস-বৃদ্ধ-নিউমোনিয়া)।', 'খাওয়া-গলতে-না-পারা-কাশি-বমি-নতুন-শ্বাস-অবরোধ (অ্যাসপিরেশন)।'],
  q=[Q('চাপ-ক্ষত প্রতিরোধে সবচেয়ে কার্যকর নিয়ম?', ['প্রতি-২ ঘণ্টায়-পাশ-পরিবর্তন', 'ত্বকে-পাউডার-মাখা', 'গরম-সেক'], 0, 'রক্ত-প্রবাহ-ফিরিয়ে-দেওয়াই একমাত্র ভিত্তি; পাউডার-গাঁট-নরম-করে-না।'),
     Q('শয্যাগত রোগীর জ্বরে-প্রথম ভাবতে-হয় কোনটি?', ['ক্ষুধা কমেছে', 'নিউমোনিয়া-মূত্র-সংক্রমণ-ত্বকের-ক্ষত', 'বদলে-কিছু-নয়'], 1, 'তিনটি-ই শয্যা-জনিত সংক্রমণ; প্রস্রাব-শ্বাস-ত্বক দেখে-নমুনা-পরীক্ষা-নির্ধারণ।')],
  final=Q('কুচিতে লাল-দাগ-চাপে-সাদা-না-হওয়া, ঘামে ভেজা বিছানা। করণীয়?', ['গরম-সেক-মালিশ', 'চাপ-মুক্তি-শুকনো-পরিষ্কার-দ্বি-ঘণ্টা-ঘূর্ণন-তালিকা', 'অ্যান্টিবায়োটিক'], 1, 'স্টেজ-১ ক্ষত-উল্টো-দ্রুত-গভীর হয়; ঘাম-আর্দ্রতা-ঘষা-প্রধান-শত্রু।'))

g('report-reading', 'রিপোর্ট পড়া: হিমোগ্লোবিন-শর্করা-কিডনি-লিভার', 'সংখ্যার ভাষা-কখন তাড়াহুড়ো, কখন-অপেক্ষা', 'science', 'practice', 'blood_immune',
  tags=['report-lab'],
  l1t='প্রধান পাঁচ-প্যানেল', intro='স্ব-ব্যাখ্যা-আতঙ্ক-বা-ভুয়া-স্বস্তি দুটোই বিপদ; প্রসঙ্গ-লক্ষণ-অনুযায়ী-ডাক্তার-পড়া-ই সিদ্ধান্ত, তবু সংখ্যা-চেনা-সহায়ক।',
  cause=['রুটিন-সেট: সিবিসি (হিমোগ্লোবিন-প্লেটলেট-ডব্লিউসি), শর্করা (এফবিজি-এইচবাইএ১সি), কিডনি (ক্রেয়াটিনিন-ইইউ-জিএফআর), লিভার (এসজিপিটি-এএলটি-আলবুমিন-বিলিরুবিন), লিপিড-প্রোফাইল।', 'ভুল-নমুনা-ক্ষার-সংগ্রহ-শূন্য-পেট-নিয়ম-না-মানা-ড্রিপ-ইনফিউশন-ঔষধ-প্রভাব (স্টেরয়েডে-শর্করা-বাড়ে)।', 'সীমা-পরি-পরিমাপাগার-ভিন্ন; গর্ভাবস্থা-বয়স-লিঙ্গ-উচ্চতা-তামাক-অবস্থান অনুযায়ী-স্বাভাবিক।', 'লুকানো কারণ: হিমোগ্লোবিন-স্বাভাবিক-তবু-ফেরিটিন-কম (প্রথম-অবস্থা); ক্রেয়াটিনিন-স্বাভাবিক-তবু-জিএফআর-৬০ নিচে (৪০+)।'],
  sym=['হিমোগ্লোবিন: পুরুষ ১৩-১৭, নারী ১২-১৫ গ্রাম/ডেসিলিটার; ১০ নিচে-শ্বাসকষ্ট-দ্রুত-চিকিৎসা।', 'শর্করা: খালি-পেটে ১০০-১২৫ প্রি-ডায়াবেটিস, ১২৬+ রোগ; এইচবাইএ১সি ৫.৭-৬.৪ প্রি, ৬.৫+ রোগ।', 'কিডনি: ক্রেয়াটিনিন-পুরুষ ০.৭-১.৩, নারী ০.৬-১.১; জিএফআর ৯০+ ভালো, ৬০ নিচে ৩ মাস-স্থায়ী-রোগ।', 'লিভার: এএলটি-এসজিপিটি ৪০ নিচে (পুরুষ-৪৫); ৫ গুণ-বেশি-জরুরি-মূল্যায়ন; অ্যালবুমিন-৩.৫ গ্রাম/ডেসিলিটার-নিচে-পুষ্টি-ক্ষতি।'],
  care=['পূরনো-রিপোর্ট-পাশে-রাখুন (তারিখ-সহ)-ক্রমাগত-পড়াই-প্রবণতা; এক-প্রতিষ্ঠান-এক-পদ্ধতি-তুলনায়-সুবিধা।', 'রুটিন-তালিকা: ৩০+ প্রি-ডায়াবেটিক-বার্ষিক; ৪৫+ লিপিড-চাপ; ডায়াবেটিকে-৩-৬ মাসে-এইচবাইএ১সি-বছরে-কিডনি-চোখ-পা।', 'লবণ-প্রমাণে-ভালো-সকাল-৮টার-নমুনা (কর্টিসোল)-সময়-নিয়ম-উল্লেখ-না-করলে ফল-অর্থ-হারা।', 'ফার্মেসি-পরামর্শ: রক্ত-পাতলা-কিডনি-ঔষধ-খাওয়া-রোগীর-রুটিন-পরীক্ষা-আবশ্যক (আইএনআর-ইইউ-পটাসিয়াম)-জিজ্ঞাসাবাদ-করুন।'],
  red=['প্লেটলেট ১ লক্ষ-নিচে বা ৫ লক্ষ-উপরে, ডব্লিউসি-অস্বাভাবিক-রক্তে-অল্প-সংখ্যক-অপরিপক্ব-কোষ—রক্ত-বিশেষজ্ঞ।', 'ক্রেয়াটিনিন-হঠাৎ-দ্বিগুণ, প্রস্রাব-কম (তীব্র-কিডনি-আঘাত)।', 'এএলটি-৫ গুণ-বেশি-হলুদ-বমি-তন্দ্রা (তীব্র-লিভার)।', 'শর্করা-৩০০+, শ্বাস-কুসমাউল-বমি-তন্দ্রা (কিটোঅ্যাসিডোসিস)-আজই-জরুরি।'],
  q=[Q('এইচবাইএ১সি ৬.৮ অর্থ কী?', ['আজকের-শর্করা-মাত্রা', 'গড়-শর্করা-পেছনের-৩ মাস', 'লিভার-কার্যকারিতা'], 1, 'গ্লাইকোহেমোগ্লোবিন-৮-১২ সপ্তাহের-গড়-প্রতিফলিত-রোগ-নিয়ন্ত্রণ-নির্ধারণ-চিকিৎসা-পরিবর্তনে।'),
     Q('কোনটি রিপোর্ট-পড়ার সবচেয়ে বড় ভুল?', ['ল্যাব-সীমা-দেখে-নেওয়া', 'লক্ষণ-ঔষধ-প্রসঙ্গ-ডাক্তার-ব্যাখ্যা-না-নেওয়া', 'তারিখ-উল্লেখ'], 1, 'একই সংখ্যা-গর্ভাবস্থায়-উচ্চতায়-ঔষধে-ভিন্ন-অর্থ; প্রসঙ্গ ছাড়া ব্যাখ্যা-বিপদ।')],
  final=Q('৫২ বছরের-ক্রেয়াটিনিন-১.৪ (৬ মাস-আগে ০.৯), জিএফআর-৫৫। করণীয়?', ['স্বাভাবিক-বয়সে-কম-ভেবে-ছাড়', 'পুনরাবৃত্তি-নমুনা-প্রস্রাব-অ্যালবুমিন-ও-চিকিৎসকের-পরামর্শ', 'নিজে-ডাইউরেটিক-শুরু'], 1, 'ক্রম-উন্নতি-হ্রাস মানে অগ্রসরমান-কিডনি; পুনরাবৃত্তি-নিশ্চিত-করে-নিয়ন্ত্রণ-ঔষধ-পরিবর্তন-বাঁচায়।'))

g('lab-sample-routine', 'নমুনা-সংগ্রহ ও পরীক্ষাগার-অনুশীলন', 'খালি-পেট-সময়-কনটেনার-চিহ্ন-ট্রান্সপোর্ট—ভুল-নমুনায় ভুল-চিকিৎসা', 'medication', 'practice', 'blood_immune',
  tags=['report-lab'],
  l1t='নমুনার আগ-পর নিয়ম', intro='রিপোর্টের নির্ভুলতা-নমুনা-শুরু হয়: প্রস্তুতি-পাত্র-সময়-চিহ্ন-তাপ; ৭০ শতাংশ ভুল-পূর্ব-বিশ্লেষণ-ধাপেই হয়।',
  cause=['প্রস্তুতি-ভুল: খালি-পেট-৮-১২ ঘণ্টা (লিপিড-গ্লুকোজ)-চা-কফি-মশলা-চুইংগামও-বাধা; ঔষধ-জিজ্ঞেস-করে-নিন।', 'পাত্র-ভুল: ইউরিন-কালচারে-জীবাণুমুক্ত-মধ্যপ্রবাহ-প্লাস্টিক, সিবিসি-ইডিটিএ-টিউব, গ্লুকোজ-সোডিয়াম-ফ্লোরাইড-গ্রে-ক্যাপ।', 'সময়-ভুল: কর্টিসোল-সকাল-৮টা, হরমোন-চক্র-নির্ধারিত, ব-সপ্তাহ-মূত্র-শীত-৪ ঘণ্টায়-না-পৌঁছালে-ফ্রিজ।', 'শুশ্রূষা-নিকাশ: সিরিঞ্জ-নিডল-শার্পস-বিন, লেবেল-নাম-আয়-তারিখ-সময়-শিরা-প্রবেশ-অবস্থান।'],
  sym=['ভুল-নমুনার ফল: হিমোলাইসিস (সিরাম লাল, পটাসিয়াম মিথ্যে বেশি)-নমুনায় জমাট (ইডিটিএ-টিউব ভরা না-হলে রক্ত-গণনা ভুল)-ত্বক-দূষণ (মূত্রে সংক্রমণ মিথ্যে ধরা)।', 'শিশু-প্রবীণ-রক্ত-পাতলা-ঔষধ-জটিলতা: টার্নিকুয়েট ১ মিনিটের বেশি-আঙুল জোরে চেপে হিমোলাইসিস-গণনা-ভুল।', 'মূত্র-সংগ্রহ: সকাল-প্রথম-মূত্র, বাইরে ধুয়ে মধ্য-ধারা, ৩০ মিনিটে-পরীক্ষা; ২৪-ঘণ্টা-সংগ্রহে প্রিজারভেটিভ-ও ঠান্ডা রাখা।', 'কালচার অ্যান্টিবায়োটিক-শুরু করার আগে; না-জানালে ফল মিথ্যে-নেগেটিভ-হয়-নাম-তারিখ লিখে দিন।'],
  care=['ট্রান্সপোর্ট: মূত্র-কালচার ২ ঘণ্টার-নিচে ৪ ডিগ্রিতে, সিরোলজি ২৪ ঘণ্টা; হিমোলাইসিস এড়াতে ২ ঘণ্টার মধ্যে সেন্ট্রিফিউজ।', 'চিহ্নিত-ফর্মা: নাম-বয়স-লিঙ্গ-তারিখ-সময়-ঔষধ-রোগ-প্রসঙ্গ-রোগী-নম্বর; দুই-রোগীর নমুনা-পাশাপাশি ধরবেন না।', 'দ্বৈত-চেক: শিরা-ছিদ্র-পরিবর্তন, টিউব-উল্টানো (৮-১০ বার), রক্ত-তরল-অনুপাত ৯:১—কম-ভরা টিউবে প্লেটলেট-আইএনআর ভুল।', 'নতুন-কর্মী-শিক্ষা: হাত-ধোয়া-গ্লাভস-শার্পস-বক্স-স্পিল-প্রটোকল-জীবাণুনাশক-ক্ষত-পরিসর-তালিকা-সতর্কতা।'],
  red=['রক্ত-ক্ষতে-অসাড়মর-ফোলা-রক্ত-জমা (শিরা-জ্বালা-থ্রম্বোফ্লেবিটাইটিস)।', 'সিরিঞ্জ-আঘাতে-রক্ত-ক্ষত-জীবাণু-সংক্রমণ-তদন্ত-পরিবেশে-প্রোটোকল।', 'ভয়-শ্বাসকষ্ট-হৃদস্পন্দন (ভেজোভাগাল-রিঅ্যাকশন)-শয্যা-পায়-উঁচু-পর্যবেক্ষণ।', 'নমুনা-হারানো-মিশ্রণ-দুই-রোগীর-রিপোর্ট-পরিবর্তন (ঘটনা-রিপোর্ট-প্রয়োজন)।'],
  q=[Q('লিপিড-প্রোফাইলের আগে নিয়ম?', ['২ ঘণ্টা-খাওয়া-বন্ধ', '৮-১২ ঘণ্টা-খালি-পেট (জল-চলে)', 'চিনি-যুক্ত চা'], 1, 'ট্রাইগ্লিসেরাইড-খাবারে-দ্রুত-বাড়ে; ৮-১২ ঘণ্টা-নিরাপদ-প্রস্তুতি।'),
     Q('মূত্র-কালচারে ভুল-সংক্রমণ-নিবারণ?', ['পাত্র-মুড়ে-সংগ্রহ-রাতে-তাপ', 'জীবাণুমুক্ত-মধ্যপ্রবাহ-৩০ মিনিটে-পরীক্ষা', 'খাওয়ার-জল-মেশানো'], 1, 'ত্বক-দূষণ-মিথ্যে-পজিটিভ; মধ্য-প্রবাহ-ঠান্ডা-দ্রুত-পরিবহনই মান-রক্ষা।')],
  final=Q('শিরা-রক্তে ট্রাই-সোডিয়াম-সিট্রেট-টিউব অর্ধেক-ভরা। ফল?', ['কোনো প্রভাব নেই', 'জমাট-গড়ানো-অনুপাত-ভুল-আইএনআর-বেশি দেখায়', 'পটাসিয়াম-কমে'], 1, 'ঔষধ-রক্ত-অনুপাত ৯:১ না-হলে ক্লটিং-কাইনেটিক্স-ভুল; নতুন-পূর্ণ-টিউব-লাগে।'))


# ---------------------------------------------------------------------------
# Reading back what is already shipped
# ---------------------------------------------------------------------------

NOTICE = 'শিক্ষামূলক সাধারণ জ্ঞান; কোনো ব্যক্তিগত প্রেসক্রিপশন নয়।'

# Every icon key LearningVisuals.iconFor can actually resolve; anything else
# silently degrades to a generic book, so an unpublished key is a bug.
ICONS = {
    'hearing', 'psychology', 'brain', 'heart', 'favorite', 'air', 'lungs',
    'restaurant', 'stomach', 'science', 'liver', 'water_drop', 'kidney',
    'tune', 'hormone', 'accessibility_new', 'bone', 'spa', 'skin', 'visibility',
    'eye', 'female', 'reproductive', 'bloodtype', 'blood', 'bedtime', 'mind',
    'coronavirus', 'shield', 'local_dining', 'nutrition', 'emergency',
    'elderly', 'child', 'medication', 'tooth',
}


def _read(name):
    path = os.path.join(OUT_DIR, name)
    with open(path, encoding='utf8') as handle:
        return json.load(handle)


def _shipped_assets():
    """Every learning json except the shelves and the atlas this tool owns."""
    for path in sorted(glob.glob(os.path.join(OUT_DIR, '*.json'))):
        name = os.path.basename(path)
        if name.startswith('library_') or name == 'body_systems_atlas.json':
            continue
        yield name, _read(name)


def shipped_ids():
    """(course ids, body-system ids) already on disk, from the hand-authored sets."""
    courses, systems = set(), set()
    for _name, data in _shipped_assets():
        if not isinstance(data, dict):
            continue
        for course in data.get('courses') or []:
            if isinstance(course, dict) and 'id' in course:
                courses.add(course['id'])
        for system in data.get('body_systems') or []:
            if isinstance(system, dict) and 'id' in system:
                systems.add(system['id'])
        sample = data.get('sample_course')
        if isinstance(sample, dict) and 'id' in sample:
            courses.add(sample['id'])
    return courses, systems


def load_library():
    """{track: courses} for the shelves written on an earlier run."""
    shelves = {}
    for path in sorted(glob.glob(os.path.join(OUT_DIR, 'library_*.json'))):
        name = os.path.basename(path)
        if name == 'library_tracks.json':
            continue  # the shelf index, not a shelf of courses
        track = name[len('library_'):-len('.json')]
        shelves[track] = _read(name)['courses']
    return shelves


def load_atlas():
    path = os.path.join(OUT_DIR, 'body_systems_atlas.json')
    if not os.path.exists(path):
        return []
    return _read('body_systems_atlas.json')['body_systems']


# Rows the guides tag but the first atlas pass never carried. Keeping them here
# means a fresh checkout regains them, and `link_atlas` fills their courses.
EXTRA_ROWS = [
    {
        'id': 'kidney-ureter',
        'name_bn': 'কিডনি ও প্রস্রাপ-নালী',
        'name_en': 'Kidney & Urinary Tract',
        'description_bn': 'কিডনির ছাঁকনি, নালী ও মূত্রথলির সংক্রমণ, পাথর আর প্রস্রাপ-নিয়ন্ত্রণের সমস্যা।',
        'description_en': 'Kidney filters, ureters and bladder: infection, stones and control problems.',
        'icon_key': 'water_drop',
        'group': 'organ',
        'body_parts': [
            {
                'id': 'kidney-ureter-part1',
                'body_system_id': 'kidney-ureter',
                'name_bn': 'কিডনির ছাঁকনি ও পাথর',
                'name_en': 'Filters, pelvis & stones',
                'description': 'রক্ত-ছাঁকনি, লবণ-জমা ও কিডনি-কাজ-কমার স্তর।',
            },
            {
                'id': 'kidney-ureter-part2',
                'body_system_id': 'kidney-ureter',
                'name_bn': 'মূত্রথলি ও প্রস্রাপ-নালী',
                'name_en': 'Bladder & urethra',
                'description': 'জ্বালা, বারবার-দৌড়, ফাঁকা-না-হওয়া ও সংক্রমণের জায়গা।',
            },
        ],
    },
    {
        'id': 'medication-safety',
        'name_bn': 'ঔষধের নিরাপদ ব্যবহার',
        'name_en': 'Medicine Safety & Self-Care Limits',
        'description_bn': 'ব্যথানাশক, অ্যান্টিবায়োটিক, ঘরোয়া-হারবল ও প্রবীণ-গর্ভাবস্থার ডোজ-সতর্কতা।',
        'description_en': 'Analgesics, antibiotics, herbal remedies and dosing cautions in pregnancy and old age.',
        'icon_key': 'medication',
        'group': 'group',
        'body_parts': [
            {
                'id': 'medication-safety-part1',
                'body_system_id': 'medication-safety',
                'name_bn': 'পেট, কিডনি ও রক্তপাতের ঝুঁকি',
                'name_en': 'Stomach, kidney & bleeding risk',
                'description': 'ব্যথানাশক-অতিরিক্ত-সেবনে ক্ষত, কিডনি-দুর্বলতা ও রক্ত-জমাট-বাঁধায়-সমস্যা।',
            },
            {
                'id': 'medication-safety-part2',
                'body_system_id': 'medication-safety',
                'name_bn': 'নির্ভরতা ও ভুল-ধারণা',
                'name_en': 'Dependence & false reassurance',
                'description': 'জ্বর-নিবারক-বার-বার, ঘরোয়া-টোটকা-ও অ্যান্টিবায়োটিক-নিজের-মতো-চালা।',
            },
        ],
    },
]


# Guides written before the atlas existed carry only a legacy body_system_id,
# which leaves them invisible on the new condition rows. Their real subjects:
RETRO_TAGS = {
    'fatigue-weakness': ['nutrition-disorders', 'report-lab'],
    'dizziness-fainting': ['ear-balance', 'report-lab'],
    'palpitation-irregular-beat': ['chest-region', 'report-lab'],
}


def merge_rows(rows):
    have = {row['id'] for row in rows}
    for row in EXTRA_ROWS:
        if row['id'] not in have:
            rows.append({k: v for k, v in row.items()})
    return rows


def retag(courses):
    for course in courses:
        wanted = RETRO_TAGS.get(course['id'])
        if not wanted:
            continue
        tags = list(course.get('atlas_tags') or [])
        for tag in wanted:
            if tag not in tags:
                tags.append(tag)
        course['atlas_tags'] = tags
    return courses


def hand_links(rows, legacy_courses):
    """Atlas links that were typed by hand against the pre-existing catalogue.

    Anything pointing at a shelf course is re-derived from its tags, so only
    links to legacy courses survive a rebuild.
    """
    return {
        row['id']: [cid for cid in row.get('related_course_ids') or []
                    if cid in legacy_courses]
        for row in rows
    }


# ---------------------------------------------------------------------------
# Self-repair and quality gates
# ---------------------------------------------------------------------------

# Devanagari, Cyrillic, CJK, Thai and Lao never belong in a Bangla guide. They
# creep in when a transliteration keyboard is mis-set; Devanagari is exactly
# 0x80 below Bengali, so it can be shifted back instead of re-typed.
FOREIGN = re.compile(
    r'[\u0900-\u097f\u0400-\u04ff\u3000-\u30ff\u4e00-\u9fff\u0e00-\u0e7f]'
)
SHIFTABLE = re.compile(r'[\u0900-\u0963\u0965-\u097f]')
BENGALI = re.compile(r'[\u0980-\u09ff]')
WORD = re.compile(r'[^\W_]+', re.UNICODE)
HTML_TAG = re.compile(r'<[^>]+>')
BRACKETED = re.compile(r'[(\[][^)\]]*[)\]]')
LATIN_RUN = re.compile(r'[A-Za-z][A-Za-z0-9]*')
ALLOWED_LATIN = {'HbA1c'}


def _purify(node):
    if isinstance(node, str):
        return SHIFTABLE.sub(lambda m: chr(ord(m.group()) + 0x80), node)
    if isinstance(node, list):
        return [_purify(v) for v in node]
    if isinstance(node, tuple):
        return tuple(_purify(v) for v in node)
    if isinstance(node, dict):
        return {k: _purify(v) for k, v in node.items()}
    return node


def _quiz_texts(item):
    yield item['question']
    for option in item['options']:
        yield option
    yield item['explanation']


def content_texts(course):
    """Only the reader-facing prose: ids, keys and enum values are English by design."""
    yield course['title']
    yield course['subtitle']
    for lesson in course['lessons']:
        yield lesson['title']
        yield lesson['summary']
        yield lesson['body']
        for point in lesson['keyPoints']:
            yield point
        for item in lesson['quiz']:
            for text in _quiz_texts(item):
                yield text
    for item in course.get('quiz') or []:
        for text in _quiz_texts(item):
            yield text


def script_problems(text):
    """Reject mixed Bengali/Latin runs and stray foreign scripts."""
    problems = []
    for word in WORD.findall(text):
        bangla = bool(BENGALI.search(word))
        foreign = bool(FOREIGN.search(word))
        latin = bool(re.search(r'[A-Za-z]', word))
        if bangla and (foreign or latin):
            problems.append('mixed-script word %r' % word)
        elif foreign:
            problems.append('foreign script in %r' % word)
    return problems


def latin_problems(text):
    """Latin is legal only as an acronym, a bracketed gloss, or HbA1c."""
    plain = HTML_TAG.sub(' ', text)
    allowed = set()
    for match in BRACKETED.finditer(plain):
        allowed.update(range(match.start(), match.end()))
    bad = []
    for match in LATIN_RUN.finditer(plain):
        word = match.group()
        if word in ALLOWED_LATIN or word.isupper():
            continue
        if any(index in allowed for index in range(match.start(), match.end())):
            continue
        bad.append(word)
    return bad


def check(courses, rows, known_systems, tracks):
    """Return every reason the catalogue must not ship."""
    problems = []
    seen = set()
    atlas_ids = {row['id'] for row in rows}
    for course in courses:
        cid = course['id']
        if cid in seen:
            problems.append('duplicate course id %s' % cid)
        seen.add(cid)
        if course.get('track') not in tracks:
            problems.append('course %s has unknown track %s' % (cid, course.get('track')))
        if course.get('body_system_id') not in known_systems:
            problems.append('course %s opens unknown body system %s'
                            % (cid, course.get('body_system_id')))
        if course.get('icon') not in ICONS:
            problems.append('course %s has icon %s that the app cannot draw'
                            % (cid, course.get('icon')))
        for tag in course.get('atlas_tags') or []:
            # A tag may name a legacy system too; those already link through
            # body_system_id, so only genuinely unknown tags are faults.
            if tag not in atlas_ids and tag not in known_systems:
                problems.append('course %s tags unknown atlas row %s' % (cid, tag))
        if len(course.get('quiz') or []) < 2:
            problems.append('course %s needs a two-question final quiz' % cid)
        for lesson in course['lessons']:
            body = lesson['body']
            if len(body) < 300:
                problems.append('lesson %s body is only %d chars' % (lesson['id'], len(body)))
            if body.count('<h3>') < 4:
                problems.append('lesson %s has %d headings, needs 4'
                                % (lesson['id'], body.count('<h3>')))
            if len(lesson['quiz']) < 2:
                problems.append('lesson %s has fewer than two quiz questions' % lesson['id'])
            for item in lesson['quiz'] + (course.get('quiz') or []):
                if not 0 <= item['answer'] < len(item['options']):
                    problems.append('quiz in %s points outside its options' % lesson['id'])
        for text in content_texts(course):
            problems += ['course %s: %s' % (cid, p) for p in script_problems(text)]
            loose = latin_problems(text)
            if loose:
                problems.append('course %s: English %s in %r'
                                % (cid, sorted(set(loose)), text[:60]))
    for row in rows:
        if row.get('group') not in {g for g, _ in ATLAS_GROUPS}:
            problems.append('atlas %s has unknown group %s' % (row['id'], row.get('group')))
        if not row.get('related_course_ids'):
            problems.append('atlas %s has no course to open' % row['id'])
        if not row.get('body_parts'):
            problems.append('atlas %s lists no body parts' % row['id'])
        for text in [row['name_bn'], row['description_bn']] + [
            part[field]
            for part in row.get('body_parts') or []
            for field in ('name_bn', 'description')
        ]:
            problems += ['atlas %s: %s' % (row['id'], p) for p in script_problems(text)]
            loose = latin_problems(text)
            if loose:
                problems.append('atlas %s: English %s in %r'
                                % (row['id'], sorted(set(loose)), text[:60]))
    return problems


# ---------------------------------------------------------------------------
# Wiring and writing
# ---------------------------------------------------------------------------

def link_atlas(rows, courses, extras):
    """Every atlas row is fed by the tags its courses carry: one source of truth."""
    for row in rows:
        ids = list(extras.get(row['id']) or [])
        for course in courses:
            if row['id'] in (course.get('atlas_tags') or []) and course['id'] not in ids:
                ids.append(course['id'])
        row['related_course_ids'] = sorted(ids)
    return rows


def _dump(name, payload):
    path = os.path.join(OUT_DIR, name)
    with open(path, 'w', encoding='utf8') as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    return path


def write(shelves, rows):
    written = []
    for track, _label in TRACKS:
        courses = shelves.get(track)
        if not courses:
            continue
        written.append(_dump('library_%s.json' % track, {
            'version': 1, 'notice': NOTICE, 'courses': courses,
        }))
    written.append(_dump('body_systems_atlas.json', {'version': 1, 'body_systems': rows}))
    written.append(_dump('library_tracks.json', {
        'version': 1,
        'tracks': [{'id': t, 'label_bn': l} for t, l in TRACKS],
    }))
    return written


def main():
    for index, course in enumerate(NEW_COURSES):
        NEW_COURSES[index] = _purify(course)

    legacy_courses, legacy_systems = shipped_ids()
    shelves = load_library()
    rows = merge_rows(load_atlas())
    extras = hand_links(rows, legacy_courses - {c['id'] for cs in shelves.values() for c in cs})

    for course in NEW_COURSES:
        bucket = shelves.setdefault(course['track'], [])
        if any(existing['id'] == course['id'] for existing in bucket):
            continue
        bucket.append(course)

    courses = retag([c for bucket in shelves.values() for c in bucket])
    link_atlas(rows, courses, extras)

    problems = check(courses, rows, legacy_systems | {r['id'] for r in rows},
                     {t for t, _ in TRACKS})
    if problems:
        for problem in problems:
            print('  %s' % problem)
        print('refusing to write: %d problem(s)' % len(problems))
        return 1

    lessons = sum(len(c['lessons']) for c in courses)
    for path in write(shelves, rows):
        print('  wrote %s' % os.path.relpath(path, OUT_DIR))
    print('%d guides authored, %d shelf courses, %d lessons, %d atlas rows'
          % (len(NEW_COURSES), len(courses), lessons, len(rows)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

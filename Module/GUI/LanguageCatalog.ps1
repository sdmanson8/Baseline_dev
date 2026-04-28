# Shared language display catalog for the Baseline GUI.
# Returns the native/English display names for every supported locale and
# builds a sortable entry list filtered against the localization directory
# on disk. Consumed by BuildPrimaryTabs.ps1 (header language popup) and
# DialogHelpers.ps1 (settings dialog language picker) so the two stay in
# lockstep without duplicating the 124-entry map.

function Get-GuiLanguageDisplayData
{
	[CmdletBinding()]
	[OutputType([hashtable])]
	param()

	if ($Script:GuiLanguageDisplayDataCache) { return $Script:GuiLanguageDisplayDataCache }

	$Script:GuiLanguageDisplayDataCache = @{
		'af'      = @{ Native = 'Afrikaans';           English = 'Afrikaans' }
		'am'      = @{ Native = 'አማርኛ';               English = 'Amharic' }
		'ar'      = @{ Native = 'العربية';              English = 'Arabic' }
		'az'      = @{ Native = 'Azərbaycan';          English = 'Azerbaijani' }
		'be'      = @{ Native = 'Беларуская';          English = 'Belarusian' }
		'bg'      = @{ Native = 'Български';           English = 'Bulgarian' }
		'bn'      = @{ Native = 'বাংলা';                English = 'Bengali' }
		'bs'      = @{ Native = 'Bosanski';            English = 'Bosnian' }
		'ca'      = @{ Native = 'Català';              English = 'Catalan' }
		'cs'      = @{ Native = 'Čeština';             English = 'Czech' }
		'da'      = @{ Native = 'Dansk';               English = 'Danish' }
		'de'      = @{ Native = 'Deutsch';             English = 'German' }
		'el'      = @{ Native = 'Ελληνικά';            English = 'Greek' }
		'en'      = @{ Native = 'English';             English = 'English' }
		'en-029'  = @{ Native = 'English (Caribbean)'; English = 'English (Caribbean)' }
		'en-AE'   = @{ Native = 'English (United Arab Emirates)'; English = 'English (United Arab Emirates)' }
		'en-AU'   = @{ Native = 'English (Australia)'; English = 'English (Australia)' }
		'en-BZ'   = @{ Native = 'English (Belize)';    English = 'English (Belize)' }
		'en-CA'   = @{ Native = 'English (Canada)';    English = 'English (Canada)' }
		'en-GB'   = @{ Native = 'English (United Kingdom)'; English = 'English (United Kingdom)' }
		'en-IE'   = @{ Native = 'English (Ireland)';   English = 'English (Ireland)' }
		'en-IN'   = @{ Native = 'English (India)';      English = 'English (India)' }
		'en-JM'   = @{ Native = 'English (Jamaica)';    English = 'English (Jamaica)' }
		'en-MV'   = @{ Native = 'English (Maldives)';   English = 'English (Maldives)' }
		'en-MY'   = @{ Native = 'English (Malaysia)';   English = 'English (Malaysia)' }
		'en-NZ'   = @{ Native = 'English (New Zealand)'; English = 'English (New Zealand)' }
		'en-PH'   = @{ Native = 'English (Philippines)'; English = 'English (Philippines)' }
		'en-SG'   = @{ Native = 'English (Singapore)';  English = 'English (Singapore)' }
		'en-TT'   = @{ Native = 'English (Trinidad & Tobago)'; English = 'English (Trinidad & Tobago)' }
		'en-US'   = @{ Native = 'English (United States)'; English = 'English (United States)' }
		'en-ZA'   = @{ Native = 'English (South Africa)'; English = 'English (South Africa)' }
		'en-ZW'   = @{ Native = 'English (Zimbabwe)';    English = 'English (Zimbabwe)' }
		'es'      = @{ Native = 'Español';             English = 'Spanish' }
		'es-MX'   = @{ Native = 'Español (México)';    English = 'Spanish (Mexico)' }
		'et'      = @{ Native = 'Eesti';               English = 'Estonian' }
		'eu'      = @{ Native = 'Euskara';             English = 'Basque' }
		'fa'      = @{ Native = 'فارسی';               English = 'Persian' }
		'fi'      = @{ Native = 'Suomi';               English = 'Finnish' }
		'fil'     = @{ Native = 'Filipino';            English = 'Filipino' }
		'fr'      = @{ Native = 'Français';            English = 'French' }
		'fr-CA'   = @{ Native = 'Français (Canada)';   English = 'French (Canada)' }
		'ga'      = @{ Native = 'Gaeilge';             English = 'Irish' }
		'gd'      = @{ Native = 'Gàidhlig';            English = 'Scottish Gaelic' }
		'gl'      = @{ Native = 'Galego';              English = 'Galician' }
		'gu'      = @{ Native = 'ગુજરાતી';              English = 'Gujarati' }
		'he'      = @{ Native = 'עברית';               English = 'Hebrew' }
		'hi'      = @{ Native = 'हिन्दी';                English = 'Hindi' }
		'hr'      = @{ Native = 'Hrvatski';            English = 'Croatian' }
		'hu'      = @{ Native = 'Magyar';              English = 'Hungarian' }
		'hy'      = @{ Native = 'Հայերեն';             English = 'Armenian' }
		'id'      = @{ Native = 'Bahasa Indonesia';    English = 'Indonesian' }
		'is'      = @{ Native = 'Íslenska';            English = 'Icelandic' }
		'it'      = @{ Native = 'Italiano';            English = 'Italian' }
		'ja'      = @{ Native = '日本語';               English = 'Japanese' }
		'ka'      = @{ Native = 'ქართული';             English = 'Georgian' }
		'kk'      = @{ Native = 'Қазақ';               English = 'Kazakh' }
		'km'      = @{ Native = 'ខ្មែរ';                 English = 'Khmer' }
		'kn'      = @{ Native = 'ಕನ್ನಡ';                English = 'Kannada' }
		'ko'      = @{ Native = '한국어';               English = 'Korean' }
		'lo'      = @{ Native = 'ລາວ';                 English = 'Lao' }
		'lt'      = @{ Native = 'Lietuvių';            English = 'Lithuanian' }
		'lv'      = @{ Native = 'Latviešu';            English = 'Latvian' }
		'mk'      = @{ Native = 'Македонски';          English = 'Macedonian' }
		'ml'      = @{ Native = 'മലയാളം';              English = 'Malayalam' }
		'mr'      = @{ Native = 'मराठी';                English = 'Marathi' }
		'ms'      = @{ Native = 'Bahasa Melayu';       English = 'Malay' }
		'mt'      = @{ Native = 'Malti';               English = 'Maltese' }
		'nb'      = @{ Native = 'Norsk Bokmål';        English = 'Norwegian' }
		'ne'      = @{ Native = 'नेपाली';               English = 'Nepali' }
		'nl'      = @{ Native = 'Nederlands';          English = 'Dutch' }
		'nl-BE'   = @{ Native = 'Nederlands (België)'; English = 'Dutch (Belgium)' }
		'nn'      = @{ Native = 'Norsk Nynorsk';       English = 'Norwegian Nynorsk' }
		'pa'      = @{ Native = 'ਪੰਜਾਬੀ';               English = 'Punjabi' }
		'pl'      = @{ Native = 'Polski';              English = 'Polish' }
		'pt'      = @{ Native = 'Português';           English = 'Portuguese' }
		'pt-BR'   = @{ Native = 'Português (Brasil)';  English = 'Portuguese (Brazil)' }
		'ro'      = @{ Native = 'Română';              English = 'Romanian' }
		'ru'      = @{ Native = 'Русский';             English = 'Russian' }
		'sk'      = @{ Native = 'Slovenčina';          English = 'Slovak' }
		'sl'      = @{ Native = 'Slovenščina';         English = 'Slovenian' }
		'sq'      = @{ Native = 'Shqip';               English = 'Albanian' }
		'sr'      = @{ Native = 'Srpski';              English = 'Serbian' }
		'sv'      = @{ Native = 'Svenska';             English = 'Swedish' }
		'sw'      = @{ Native = 'Kiswahili';           English = 'Swahili' }
		'ta'      = @{ Native = 'தமிழ்';                English = 'Tamil' }
		'te'      = @{ Native = 'తెలుగు';               English = 'Telugu' }
		'th'      = @{ Native = 'ไทย';                  English = 'Thai' }
		'tr'      = @{ Native = 'Türkçe';              English = 'Turkish' }
		'uk'      = @{ Native = 'Українська';          English = 'Ukrainian' }
		'ur'      = @{ Native = 'اردو';                 English = 'Urdu' }
		'uz'      = @{ Native = "O'zbek";              English = 'Uzbek' }
		'vi'      = @{ Native = 'Tiếng Việt';          English = 'Vietnamese' }
		'zh-Hans' = @{ Native = '简体中文';              English = 'Chinese (Simplified)' }
		'zh-Hant' = @{ Native = '繁體中文';              English = 'Chinese (Traditional)' }
		'as'      = @{ Native = 'অসমীয়া';              English = 'Assamese' }
		'bn-BD'   = @{ Native = 'বাংলা (বাংলাদেশ)';     English = 'Bengali (Bangladesh)' }
		'ckb'     = @{ Native = 'کوردیی ناوەندی';       English = 'Central Kurdish' }
		'cy'      = @{ Native = 'Cymraeg';             English = 'Welsh' }
		'ha'      = @{ Native = 'Hausa';               English = 'Hausa' }
		'ig'      = @{ Native = 'Igbo';                English = 'Igbo' }
		'kok'     = @{ Native = 'कोंकणी';               English = 'Konkani' }
		'ky'      = @{ Native = 'Кыргызча';            English = 'Kyrgyz' }
		'lb'      = @{ Native = 'Lëtzebuergesch';      English = 'Luxembourgish' }
		'mi'      = @{ Native = 'Te Reo Māori';        English = 'Māori' }
		'mn'      = @{ Native = 'Монгол';              English = 'Mongolian' }
		'nso'     = @{ Native = 'Sesotho sa Leboa';    English = 'Northern Sotho' }
		'or'      = @{ Native = 'ଓଡ଼ିଆ';                English = 'Odia' }
		'pa-Arab' = @{ Native = 'پنجابی';               English = 'Punjabi (Arabic)' }
		'prs'     = @{ Native = 'دری';                  English = 'Dari' }
		'ps'      = @{ Native = 'پښتو';                 English = 'Pashto' }
		'qu'      = @{ Native = 'Runasimi';            English = 'Quechua' }
		'quc'     = @{ Native = "K'iche'";             English = "K'iche'" }
		'rw'      = @{ Native = 'Ikinyarwanda';        English = 'Kinyarwanda' }
		'sd'      = @{ Native = 'سنڌي';                 English = 'Sindhi' }
		'si'      = @{ Native = 'සිංහල';                English = 'Sinhala' }
		'sr-Cyrl' = @{ Native = 'Српски';              English = 'Serbian (Cyrillic)' }
		'ti'      = @{ Native = 'ትግርኛ';                English = 'Tigrinya' }
		'tk'      = @{ Native = 'Türkmen';             English = 'Turkmen' }
		'tn'      = @{ Native = 'Setswana';            English = 'Setswana' }
		'tt'      = @{ Native = 'Татар';               English = 'Tatar' }
		'ug'      = @{ Native = 'ئۇيغۇرچە';             English = 'Uyghur' }
		'wo'      = @{ Native = 'Wolof';               English = 'Wolof' }
		'xh'      = @{ Native = 'isiXhosa';            English = 'isiXhosa' }
		'yo'      = @{ Native = 'Yorùbá';              English = 'Yoruba' }
		'zu'      = @{ Native = 'isiZulu';             English = 'isiZulu' }
	}

	return $Script:GuiLanguageDisplayDataCache
}

function Get-GuiLanguageEntries
{
	[CmdletBinding()]
	[OutputType([System.Collections.ArrayList])]
	param(
		[string]$LocalizationDirectory
	)

	$langDisplayData = Get-GuiLanguageDisplayData
	$entries = New-Object System.Collections.ArrayList

	if ([string]::IsNullOrWhiteSpace([string]$LocalizationDirectory)) { return ,$entries }
	if (-not (Test-Path -LiteralPath $LocalizationDirectory)) { return ,$entries }

	# Locale JSON files live in per-language folders; the root JSON files are
	# metadata (locale-map, schema, exempt-keys) and must not appear in the picker.
	$languageFiles = @(
		Get-ChildItem -LiteralPath $LocalizationDirectory -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue |
			Where-Object { $langDisplayData.ContainsKey($_.BaseName) } |
			Sort-Object @{ Expression = { if ($langDisplayData.ContainsKey($_.BaseName)) { $langDisplayData[$_.BaseName].English } else { $_.BaseName } } }, BaseName
	)

	foreach ($jsonFile in $languageFiles)
	{
		$code = $jsonFile.BaseName
		$nativeName = if ($langDisplayData.ContainsKey($code)) { $langDisplayData[$code].Native } else { $code }
		$englishName = if ($langDisplayData.ContainsKey($code)) { $langDisplayData[$code].English } else { $code }
		[void]$entries.Add([pscustomobject]@{
			Code = $code
			DisplayName = $englishName
			NativeName = $nativeName
			EnglishName = $englishName
			SearchIndex = ("{0} {1} {2} {3}" -f $nativeName, $englishName, $code, ($code -replace '-', ' ')).ToLowerInvariant()
		})
	}

	return ,$entries
}

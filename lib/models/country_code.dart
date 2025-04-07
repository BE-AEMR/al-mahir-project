class CountryCode {
  final String name;
  final String dialCode;
  final String code;
  final String example;

  CountryCode({
    required this.name,
    required this.dialCode,
    required this.code,
    required this.example,
  });

  // Surcharger l'opérateur d'égalité pour permettre la comparaison correcte des instances
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CountryCode &&
        other.name == name &&
        other.dialCode == dialCode &&
        other.code == code;
  }

  // Surcharger hashCode pour respecter la convention: si a == b, alors a.hashCode == b.hashCode
  @override
  int get hashCode => name.hashCode ^ dialCode.hashCode ^ code.hashCode;

  // Méthode pour filtrer la liste des pays par recherche
  static List<CountryCode> search(String query) {
    if (query.isEmpty) {
      return getAll();
    }
    
    final lowercaseQuery = query.toLowerCase();
    return getAll().where((country) {
      return country.name.toLowerCase().contains(lowercaseQuery) ||
          country.dialCode.contains(query) ||
          country.code.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  static List<CountryCode> getAll() {
    return [
      // Afrique
      CountryCode(
        name: 'Afrique du Sud',
        dialCode: '+27',
        code: 'ZA',
        example: '71 234 5678',
      ),
      CountryCode(
        name: 'Algérie',
        dialCode: '+213',
        code: 'DZ',
        example: '551 234 567',
      ),
      CountryCode(
        name: 'Angola',
        dialCode: '+244',
        code: 'AO',
        example: '923 456 789',
      ),
      CountryCode(
        name: 'Bénin',
        dialCode: '+229',
        code: 'BJ',
        example: '90 123 456',
      ),
      CountryCode(
        name: 'Botswana',
        dialCode: '+267',
        code: 'BW',
        example: '71 234 567',
      ),
      CountryCode(
        name: 'Burkina Faso',
        dialCode: '+226',
        code: 'BF',
        example: '70 12 34 56',
      ),
      CountryCode(
        name: 'Burundi',
        dialCode: '+257',
        code: 'BI',
        example: '79 56 12 34',
      ),
      CountryCode(
        name: 'Cameroun',
        dialCode: '+237',
        code: 'CM',
        example: '6 71 23 45 67',
      ),
      CountryCode(
        name: 'Cap-Vert',
        dialCode: '+238',
        code: 'CV',
        example: '991 23 45',
      ),
      CountryCode(
        name: 'Centrafrique',
        dialCode: '+236',
        code: 'CF',
        example: '70 01 23 45',
      ),
      CountryCode(
        name: 'Comores',
        dialCode: '+269',
        code: 'KM',
        example: '321 23 45',
      ),
      CountryCode(
        name: 'Congo',
        dialCode: '+242',
        code: 'CG',
        example: '06 123 4567',
      ),
      CountryCode(
        name: 'Côte d\'Ivoire',
        dialCode: '+225',
        code: 'CI',
        example: '01 23 45 67 89',
      ),
      CountryCode(
        name: 'Djibouti',
        dialCode: '+253',
        code: 'DJ',
        example: '77 83 10 01',
      ),
      CountryCode(
        name: 'Égypte',
        dialCode: '+20',
        code: 'EG',
        example: '10 123 4567',
      ),
      CountryCode(
        name: 'Érythrée',
        dialCode: '+291',
        code: 'ER',
        example: '7 123 456',
      ),
      CountryCode(
        name: 'Éthiopie',
        dialCode: '+251',
        code: 'ET',
        example: '91 123 4567',
      ),
      CountryCode(
        name: 'Gabon',
        dialCode: '+241',
        code: 'GA',
        example: '06 03 12 34',
      ),
      CountryCode(
        name: 'Gambie',
        dialCode: '+220',
        code: 'GM',
        example: '301 2345',
      ),
      CountryCode(
        name: 'Ghana',
        dialCode: '+233',
        code: 'GH',
        example: '20 123 4567',
      ),
      CountryCode(
        name: 'Guinée',
        dialCode: '+224',
        code: 'GN',
        example: '601 12 34 56',
      ),
      CountryCode(
        name: 'Guinée-Bissau',
        dialCode: '+245',
        code: 'GW',
        example: '955 012 345',
      ),
      CountryCode(
        name: 'Guinée équatoriale',
        dialCode: '+240',
        code: 'GQ',
        example: '222 123 456',
      ),
      CountryCode(
        name: 'Kenya',
        dialCode: '+254',
        code: 'KE',
        example: '712 345678',
      ),
      CountryCode(
        name: 'Lesotho',
        dialCode: '+266',
        code: 'LS',
        example: '5012 3456',
      ),
      
      // Europe
      CountryCode(
        name: 'Allemagne',
        dialCode: '+49',
        code: 'DE',
        example: '151 1234567',
      ),
      CountryCode(
        name: 'Autriche',
        dialCode: '+43',
        code: 'AT',
        example: '664 123456',
      ),
      CountryCode(
        name: 'Belgique',
        dialCode: '+32',
        code: 'BE',
        example: '470 12 34 56',
      ),
      CountryCode(
        name: 'Bulgarie',
        dialCode: '+359',
        code: 'BG',
        example: '87 123 4567',
      ),
      CountryCode(
        name: 'Croatie',
        dialCode: '+385',
        code: 'HR',
        example: '91 234 5678',
      ),
      CountryCode(
        name: 'Danemark',
        dialCode: '+45',
        code: 'DK',
        example: '20 12 34 56',
      ),
      CountryCode(
        name: 'Espagne',
        dialCode: '+34',
        code: 'ES',
        example: '612 345 678',
      ),
      CountryCode(
        name: 'Estonie',
        dialCode: '+372',
        code: 'EE',
        example: '512 3456',
      ),
      CountryCode(
        name: 'Finlande',
        dialCode: '+358',
        code: 'FI',
        example: '41 2345678',
      ),
      CountryCode(
        name: 'France',
        dialCode: '+33',
        code: 'FR',
        example: '6 12 34 56 78',
      ),
      CountryCode(
        name: 'Grèce',
        dialCode: '+30',
        code: 'GR',
        example: '691 234 5678',
      ),
      CountryCode(
        name: 'Hongrie',
        dialCode: '+36',
        code: 'HU',
        example: '20 123 4567',
      ),
      CountryCode(
        name: 'Irlande',
        dialCode: '+353',
        code: 'IE',
        example: '85 123 4567',
      ),
      CountryCode(
        name: 'Italie',
        dialCode: '+39',
        code: 'IT',
        example: '312 345 6789',
      ),
      CountryCode(
        name: 'Lettonie',
        dialCode: '+371',
        code: 'LV',
        example: '21 234 567',
      ),
      CountryCode(
        name: 'Lituanie',
        dialCode: '+370',
        code: 'LT',
        example: '612 34567',
      ),
      CountryCode(
        name: 'Luxembourg',
        dialCode: '+352',
        code: 'LU',
        example: '628 123 456',
      ),
      CountryCode(
        name: 'Macédoine du Nord',
        dialCode: '+389',
        code: 'MK',
        example: '72 345 678',
      ),
      CountryCode(
        name: 'Malte',
        dialCode: '+356',
        code: 'MT',
        example: '9656 7890',
      ),
      CountryCode(
        name: 'Moldavie',
        dialCode: '+373',
        code: 'MD',
        example: '621 23 456',
      ),
      CountryCode(
        name: 'Monaco',
        dialCode: '+377',
        code: 'MC',
        example: '6 12 34 56 78',
      ),
      CountryCode(
        name: 'Monténégro',
        dialCode: '+382',
        code: 'ME',
        example: '67 622 901',
      ),
      CountryCode(
        name: 'Norvège',
        dialCode: '+47',
        code: 'NO',
        example: '406 12 345',
      ),
      CountryCode(
        name: 'Pays-Bas',
        dialCode: '+31',
        code: 'NL',
        example: '6 12345678',
      ),
      CountryCode(
        name: 'Pologne',
        dialCode: '+48',
        code: 'PL',
        example: '512 345 678',
      ),
      CountryCode(
        name: 'Portugal',
        dialCode: '+351',
        code: 'PT',
        example: '912 345 678',
      ),
      CountryCode(
        name: 'République tchèque',
        dialCode: '+420',
        code: 'CZ',
        example: '601 123 456',
      ),
      CountryCode(
        name: 'Roumanie',
        dialCode: '+40',
        code: 'RO',
        example: '712 345 678',
      ),
      CountryCode(
        name: 'Royaume-Uni',
        dialCode: '+44',
        code: 'GB',
        example: '7400 123456',
      ),
      CountryCode(
        name: 'Russie',
        dialCode: '+7',
        code: 'RU',
        example: '9 123 456-78-90',
      ),
      CountryCode(
        name: 'Serbie',
        dialCode: '+381',
        code: 'RS',
        example: '601 234567',
      ),
      CountryCode(
        name: 'Slovaquie',
        dialCode: '+421',
        code: 'SK',
        example: '912 123 456',
      ),
      CountryCode(
        name: 'Slovénie',
        dialCode: '+386',
        code: 'SI',
        example: '31 234 567',
      ),
      CountryCode(
        name: 'Suède',
        dialCode: '+46',
        code: 'SE',
        example: '70 123 45 67',
      ),
      CountryCode(
        name: 'Suisse',
        dialCode: '+41',
        code: 'CH',
        example: '78 123 45 67',
      ),
      CountryCode(
        name: 'Ukraine',
        dialCode: '+380',
        code: 'UA',
        example: '50 123 4567',
      ),
      
      // Asie
      CountryCode(
        name: 'Afghanistan',
        dialCode: '+93',
        code: 'AF',
        example: '70 123 4567',
      ),
      CountryCode(
        name: 'Arabie saoudite',
        dialCode: '+966',
        code: 'SA',
        example: '51 234 5678',
      ),
      CountryCode(
        name: 'Arménie',
        dialCode: '+374',
        code: 'AM',
        example: '77 123456',
      ),
      CountryCode(
        name: 'Azerbaïdjan',
        dialCode: '+994',
        code: 'AZ',
        example: '40 123 4567',
      ),
      CountryCode(
        name: 'Bahreïn',
        dialCode: '+973',
        code: 'BH',
        example: '3600 1234',
      ),
      CountryCode(
        name: 'Bangladesh',
        dialCode: '+880',
        code: 'BD',
        example: '1812 345678',
      ),
      CountryCode(
        name: 'Bhoutan',
        dialCode: '+975',
        code: 'BT',
        example: '17 12 3456',
      ),
      CountryCode(
        name: 'Birmanie',
        dialCode: '+95',
        code: 'MM',
        example: '9 123 4567',
      ),
      CountryCode(
        name: 'Brunei',
        dialCode: '+673',
        code: 'BN',
        example: '712 3456',
      ),
      CountryCode(
        name: 'Cambodge',
        dialCode: '+855',
        code: 'KH',
        example: '91 234 567',
      ),
      CountryCode(
        name: 'Chine',
        dialCode: '+86',
        code: 'CN',
        example: '131 2345 6789',
      ),
      CountryCode(
        name: 'Corée du Nord',
        dialCode: '+850',
        code: 'KP',
        example: '1 9123 4567',
      ),
      CountryCode(
        name: 'Corée du Sud',
        dialCode: '+82',
        code: 'KR',
        example: '10 1234 5678',
      ),
      CountryCode(
        name: 'Émirats arabes unis',
        dialCode: '+971',
        code: 'AE',
        example: '50 123 4567',
      ),
      CountryCode(
        name: 'Géorgie',
        dialCode: '+995',
        code: 'GE',
        example: '555 12 34 56',
      ),
      CountryCode(
        name: 'Hong Kong',
        dialCode: '+852',
        code: 'HK',
        example: '5123 4567',
      ),
      CountryCode(
        name: 'Inde',
        dialCode: '+91',
        code: 'IN',
        example: '96123 45678',
      ),
      CountryCode(
        name: 'Indonésie',
        dialCode: '+62',
        code: 'ID',
        example: '812 345 678',
      ),
      CountryCode(
        name: 'Iran',
        dialCode: '+98',
        code: 'IR',
        example: '912 345 6789',
      ),
      CountryCode(
        name: 'Irak',
        dialCode: '+964',
        code: 'IQ',
        example: '791 234 5678',
      ),
      CountryCode(
        name: 'Israël',
        dialCode: '+972',
        code: 'IL',
        example: '50 123 4567',
      ),
      CountryCode(
        name: 'Japon',
        dialCode: '+81',
        code: 'JP',
        example: '90 1234 5678',
      ),
      CountryCode(
        name: 'Jordanie',
        dialCode: '+962',
        code: 'JO',
        example: '7 9012 3456',
      ),
      CountryCode(
        name: 'Kazakhstan',
        dialCode: '+7',
        code: 'KZ',
        example: '771 000 9998',
      ),
      CountryCode(
        name: 'Kirghizistan',
        dialCode: '+996',
        code: 'KG',
        example: '700 123 456',
      ),
      CountryCode(
        name: 'Koweït',
        dialCode: '+965',
        code: 'KW',
        example: '500 12345',
      ),
      CountryCode(
        name: 'Liban',
        dialCode: '+961',
        code: 'LB',
        example: '71 123 456',
      ),
      CountryCode(
        name: 'Malaisie',
        dialCode: '+60',
        code: 'MY',
        example: '12 345 6789',
      ),
      CountryCode(
        name: 'Maldives',
        dialCode: '+960',
        code: 'MV',
        example: '771 2345',
      ),
      CountryCode(
        name: 'Mongolie',
        dialCode: '+976',
        code: 'MN',
        example: '8812 3456',
      ),
      CountryCode(
        name: 'Népal',
        dialCode: '+977',
        code: 'NP',
        example: '984 1234567',
      ),
      CountryCode(
        name: 'Oman',
        dialCode: '+968',
        code: 'OM',
        example: '9212 3456',
      ),
      CountryCode(
        name: 'Ouzbékistan',
        dialCode: '+998',
        code: 'UZ',
        example: '91 234 56 78',
      ),
      CountryCode(
        name: 'Pakistan',
        dialCode: '+92',
        code: 'PK',
        example: '301 2345678',
      ),
      CountryCode(
        name: 'Palestine',
        dialCode: '+970',
        code: 'PS',
        example: '599 123 456',
      ),
      CountryCode(
        name: 'Philippines',
        dialCode: '+63',
        code: 'PH',
        example: '905 123 4567',
      ),
      CountryCode(
        name: 'Qatar',
        dialCode: '+974',
        code: 'QA',
        example: '3312 3456',
      ),
      CountryCode(
        name: 'Singapour',
        dialCode: '+65',
        code: 'SG',
        example: '8123 4567',
      ),
      CountryCode(
        name: 'Sri Lanka',
        dialCode: '+94',
        code: 'LK',
        example: '71 234 5678',
      ),
      CountryCode(
        name: 'Syrie',
        dialCode: '+963',
        code: 'SY',
        example: '944 567 890',
      ),
      CountryCode(
        name: 'Taïwan',
        dialCode: '+886',
        code: 'TW',
        example: '912 345 678',
      ),
      CountryCode(
        name: 'Thaïlande',
        dialCode: '+66',
        code: 'TH',
        example: '81 234 5678',
      ),
      CountryCode(
        name: 'Turquie',
        dialCode: '+90',
        code: 'TR',
        example: '501 234 56 78',
      ),
      CountryCode(
        name: 'Vietnam',
        dialCode: '+84',
        code: 'VN',
        example: '91 234 56 78',
      ),
      CountryCode(
        name: 'Yémen',
        dialCode: '+967',
        code: 'YE',
        example: '712 345 678',
      ),
      
      // Amérique
      CountryCode(
        name: 'Antigua-et-Barbuda',
        dialCode: '+1268',
        code: 'AG',
        example: '268 464 1234',
      ),
      CountryCode(
        name: 'Argentine',
        dialCode: '+54',
        code: 'AR',
        example: '11 1234 5678',
      ),
      CountryCode(
        name: 'Bahamas',
        dialCode: '+1242',
        code: 'BS',
        example: '242 359 1234',
      ),
      CountryCode(
        name: 'Barbade',
        dialCode: '+1246',
        code: 'BB',
        example: '246 250 1234',
      ),
      CountryCode(
        name: 'Belize',
        dialCode: '+501',
        code: 'BZ',
        example: '622 1234',
      ),
      CountryCode(
        name: 'Bolivie',
        dialCode: '+591',
        code: 'BO',
        example: '71234567',
      ),
      CountryCode(
        name: 'Brésil',
        dialCode: '+55',
        code: 'BR',
        example: '11 91234 5678',
      ),
      CountryCode(
        name: 'Canada',
        dialCode: '+1',
        code: 'CA',
        example: '506 234 5678',
      ),
      CountryCode(
        name: 'Chili',
        dialCode: '+56',
        code: 'CL',
        example: '9 1234 5678',
      ),
      CountryCode(
        name: 'Colombie',
        dialCode: '+57',
        code: 'CO',
        example: '321 1234567',
      ),
      CountryCode(
        name: 'Costa Rica',
        dialCode: '+506',
        code: 'CR',
        example: '8312 3456',
      ),
      CountryCode(
        name: 'Cuba',
        dialCode: '+53',
        code: 'CU',
        example: '5 1234567',
      ),
      CountryCode(
        name: 'République dominicaine',
        dialCode: '+1809',
        code: 'DO',
        example: '809 555 5555',
      ),
      CountryCode(
        name: 'Équateur',
        dialCode: '+593',
        code: 'EC',
        example: '99 123 4567',
      ),
      CountryCode(
        name: 'États-Unis',
        dialCode: '+1',
        code: 'US',
        example: '202 555 0123',
      ),
      CountryCode(
        name: 'Guatemala',
        dialCode: '+502',
        code: 'GT',
        example: '5123 4567',
      ),
      CountryCode(
        name: 'Haïti',
        dialCode: '+509',
        code: 'HT',
        example: '34 10 1234',
      ),
      CountryCode(
        name: 'Honduras',
        dialCode: '+504',
        code: 'HN',
        example: '9123 4567',
      ),
      CountryCode(
        name: 'Jamaïque',
        dialCode: '+1876',
        code: 'JM',
        example: '876 210 1234',
      ),
      CountryCode(
        name: 'Mexique',
        dialCode: '+52',
        code: 'MX',
        example: '222 123 4567',
      ),
      CountryCode(
        name: 'Nicaragua',
        dialCode: '+505',
        code: 'NI',
        example: '8123 4567',
      ),
      CountryCode(
        name: 'Panama',
        dialCode: '+507',
        code: 'PA',
        example: '6123 4567',
      ),
      CountryCode(
        name: 'Paraguay',
        dialCode: '+595',
        code: 'PY',
        example: '961 456789',
      ),
      CountryCode(
        name: 'Pérou',
        dialCode: '+51',
        code: 'PE',
        example: '912 345 678',
      ),
      CountryCode(
        name: 'Uruguay',
        dialCode: '+598',
        code: 'UY',
        example: '94 231 234',
      ),
      CountryCode(
        name: 'Venezuela',
        dialCode: '+58',
        code: 'VE',
        example: '412 1234567',
      ),
      
      // Océanie
      CountryCode(
        name: 'Australie',
        dialCode: '+61',
        code: 'AU',
        example: '412 345 678',
      ),
      CountryCode(
        name: 'Fidji',
        dialCode: '+679',
        code: 'FJ',
        example: '701 2345',
      ),
      CountryCode(
        name: 'Nouvelle-Zélande',
        dialCode: '+64',
        code: 'NZ',
        example: '21 123 4567',
      ),
      CountryCode(
        name: 'Papouasie-Nouvelle-Guinée',
        dialCode: '+675',
        code: 'PG',
        example: '681 2345',
      ),
      
      // Maghreb
      CountryCode(
        name: 'Maroc',
        dialCode: '+212',
        code: 'MA',
        example: '6 61 23 45 67',
      ),
      CountryCode(
        name: 'Tunisie',
        dialCode: '+216',
        code: 'TN',
        example: '20 123 456',
      ),
      CountryCode(
        name: 'Libye',
        dialCode: '+218',
        code: 'LY',
        example: '91 2345678',
      ),
    ];
  }
}

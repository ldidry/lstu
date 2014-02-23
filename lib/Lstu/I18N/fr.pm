package Lstu::I18N::fr;
use Mojo::Base 'Lstu::I18N';

our %Lexicon = (
    'about'            => 'À propos',
    'already_taken'    => 'Le texte du raccourci ([_1]) est déjà utilisé. Veuillez en choisir un autre',
    'api'              => 'Raccourcir rapidement une URL :',
    'custom-url'       => 'Texte du raccourci personnalisé',
    'go'               => 'Allons-y !',
    'license'          => 'Licence : ',
    'no_more_short'    => 'Il n\'y a plus d\'URL raccourcie disponible. Veuillez réessayer ou contactez l\'administrateur sur [_1]. Rappel de l\'URL à raccourcir : [_2]',
    'no_valid_shorcut' => 'Le texte du raccourci ne doit contenir que des chiffres, des lettres et les caractères - et _ et ne peut être "a".',
    'no_valid_url'     => '[_1] n\'est pas une URL valide.',
    'url_not_found'    => 'L\'URL raccourcie [_1] n\'existe pas.',
    'url_to_shorten'   => 'URL à raccourcir',
);

1;

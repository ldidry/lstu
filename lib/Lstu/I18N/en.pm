package Lstu::I18N::en;
use Mojo::Base 'Lstu::I18N';

our %Lexicon = (
    'about'            => 'About',
    'already_taken'    => 'The shortened text ([_1]) is already used. Please choose another one.',
    'api'              => 'Fast way to shorten an URL:',
    'custom-url'       => 'Custom shortened text',
    'go'               => 'Go !',
    'license'          => 'License:',
    'no_more_short'    => 'No shortened URL available. Please retry or contact the administrator at [_1]. Your URL to shorten: [_2]',
    'no_valid_shorcut' => 'The shortened text can contain only numbers, letters and the - and _ characters and can\'t be "a".',
    'no_valid_url'     => '[_1] is not a valid URL.',
    'url_not_found'    => 'The shortened URL [_1] doesn\'t exist.',
    'url_to_shorten'   => 'URL to shorten',
);

1;

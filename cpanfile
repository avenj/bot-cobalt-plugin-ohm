requires "perl"       => "5.010";
requires "strictures" => "2";

on 'test'      => sub {
  requires "Test::More" => "0.88";
};

on 'configure' => sub {};
on 'build'     => sub {};
on 'runtime'   => sub {};
on 'develop'   => sub {};

#!/usr/bin/perl

use strict;
use Data::Dumper;

my $file = shift;

open IN, "$file";

my %remember;
my @data;
my %pair;
my %single;

#store data
while ( <IN> ) {

  chomp;
  my ($id, $type, $chr, $coor, $support, $pw, $ct, $repornot, $disco) = split /\t/;

  $remember{$id} .= "$_\n";

  my $data;
  $data->{'id'} = $id;
  $data->{'type'} = $type;
  $data->{'chr'} = $chr;
  $data->{'coor'} = $coor;
  $data->{'support'} = $support;
  $data->{'pw'} = $pw;
  $data->{'ct'} = $ct;
  $data->{'rep'} = $repornot;
  $data->{'disco'} = $disco;
  push @data, $data;


  if ($type eq 'p') {
    my $pid;
    $pid->{'chr'} = $chr;
    $pid->{'coor'} = $coor;
    $pid->{'su'} = $support;
    $pid->{'pw'} = $pw;
    $pid->{'ct'} = $ct;
    $pid->{'rep'} = $repornot;
    $pid->{'disco'} = $disco;
    push @{$pair{$id}}, $pid;
  }

  if ($type eq 's') {
     my $bp = $chr."\t".$coor;
     $single{$bp}{'id'} = $id;
     $single{$bp}{'su'} = $support;
     $single{$bp}{'pw'} = $pw;
     $single{$bp}{'ct'} = $ct;
     $single{$bp}{'rep'} = $repornot;
     $single{$bp}{'disco'} = $disco;
  }

}
close IN;

my %forget;
my %redundancy;

foreach my $data (@data) {

   my $id = $data->{'id'};
   my $type = $data->{'type'};
   my $chr = $data->{'chr'};
   my $coor = $data->{'coor'};
   my $support = $data->{'support'};
   my $pw = $data->{'pw'};
   my $ct = $data->{'ct'};
   my $repornot = $data->{'rep'};
   my $disco = $data->{'disco'};

   my $bp = $chr."\t".$coor;
   $redundancy{$bp}{'count'}++;      #remember how many times this $bp occur

   if ( $redundancy{$bp}{'id'} ne '' ) {

     #here is for SINGLE type
     if ( $type eq 's' ) {
       if ( $redundancy{$bp}{'type'} eq 'p' ) {    #the previous one is paired
         $forget{$id} = '';
       } else {                                    #both are single type
         if ($pw < $redundancy{$bp}{'pw'}) {
           $forget{$id} = '';
         } elsif ($pw == $redundancy{$bp}{'pw'} and $support <= $redundancy{$bp}{'su'}) {
           $forget{$id} = '';
         } else {                                  #the current one seems better
            $forget{$redundancy{$bp}{'id'}} = '';  #forget the old one
            $redundancy{$bp}{'id'} = $id;
            $redundancy{$bp}{'su'} = $support;
            $redundancy{$bp}{'type'} = $type;
            $redundancy{$bp}{'pw'} = $pw;
            $redundancy{$bp}{'ct'} = $ct;
            $redundancy{$bp}{'rep'} = $repornot;
            $redundancy{$bp}{'disco'} = $disco;
         }
       }
     }    #single type

     #here is for PAIRED type
     elsif ( $type eq 'p' ) {

       if ( $redundancy{$bp}{'type'} eq 'p' ) {      #both are paired ,compare now

          my $old_id = $redundancy{$bp}{'id'};
          my ($old_supportA, $supportA);
          my ($old_pwA, $pwA);
          foreach my $old_bp ( @{$pair{$old_id}} ){
             $old_supportA += $old_bp->{'su'};
             $old_pwA += $old_bp->{'pw'};
          }
          foreach my $new_bp ( @{$pair{$id}} ){
             $supportA += $new_bp->{'su'};
             $pwA += $new_bp->{'pw'};
          }

          if ($supportA < $old_supportA){
             $forget{$id} = '';
          } elsif ($supportA == $old_supportA and $pwA <= $old_pwA) {
             $forget{$id} = '';
          } else {                                     #the current one is better
             $forget{$redundancy{$bp}{'id'}} = '';     #forget the old one
             $redundancy{$bp}{'id'} = $id;
             $redundancy{$bp}{'su'} = $support;
             $redundancy{$bp}{'type'} = $type;
             $redundancy{$bp}{'pw'} = $pw;
             $redundancy{$bp}{'ct'} = $ct;
             $redundancy{$bp}{'rep'} = $repornot;
             $redundancy{$bp}{'disco'} = $disco;
          }

       } else {                                        #the old one is single
         $forget{$redundancy{$bp}{'id'}} = '';
         $redundancy{$bp}{'id'} = $id;
         $redundancy{$bp}{'su'} = $support;
         $redundancy{$bp}{'type'} = $type;
         $redundancy{$bp}{'pw'} = $pw;
         $redundancy{$bp}{'ct'} = $ct;
         $redundancy{$bp}{'rep'} = $repornot;
         $redundancy{$bp}{'disco'} = $disco;
       }
     }   #paired type
   }     #defined
   else {  #the bp is not defined
     $redundancy{$bp}{'id'} = $id;
     $redundancy{$bp}{'su'} = $support;
     $redundancy{$bp}{'type'} = $type;
     $redundancy{$bp}{'pw'} = $pw;
     $redundancy{$bp}{'ct'} = $ct;
     $redundancy{$bp}{'rep'} = $repornot;
     $redundancy{$bp}{'disco'} = $disco;
   }

   if ($repornot eq 'R') {
     $forget{$id} = '';
   }

   if ($chr eq 'chrM') {
     $forget{$id} = '';
   }

   if ( $type eq 'p' and $support < 3 and $pw < 5 ) {
     $forget{$id} = '';
   }

   if ( $type eq 's' and ($support < 5 or $pw < 3) ) {
     $forget{$id} = '';
   }
}


my %printed;

#scan coordinates
foreach my $bp (keys %redundancy) {
   $bp =~ /^(.+?)\t(\d+)$/;
   my $chr = $1;
   my $coor = $2;
   my $id = $redundancy{$bp}{'id'};        #the best id for this bp
   my $type = $redundancy{$bp}{'type'};
   my $support = $redundancy{$bp}{'su'};
   my $pw = $redundancy{$bp}{'pw'};
   my $ct = $redundancy{$bp}{'ct'};
   my $count = $redundancy{$bp}{'count'};
   my $repornot = $redundancy{$bp}{'rep'};
   my $disco = $redundancy{$bp}{'disco'};

   if ($type eq 's') {
     if (! exists($forget{$id})){
       if ( $disco >= 2 or ($disco == 1 and $support > 10) ) {
          print "$remember{$id}" if (!exists $printed{$id});
          $printed{$id} = '';
       }
     }
     next;
   } #type S

   #rest is type P
   my ($chr2, $coor2, $bp2, $support2, $pw2, $ct2, $count2, $repornot2, $disco2);

   if ( ${$pair{$id}}[0]->{'chr'} eq $chr and ${$pair{$id}}[0]->{'coor'} eq $coor ) {
      $chr2 = ${$pair{$id}}[1]->{'chr'};
      $coor2 = ${$pair{$id}}[1]->{'coor'};
      $bp2 = $chr2."\t".$coor2;
      $support2 = ${$pair{$id}}[1]->{'su'};
      $pw2 = ${$pair{$id}}[1]->{'pw'};
      $ct2 = ${$pair{$id}}[1]->{'ct'};
      $repornot2 = ${$pair{$id}}[1]->{'rep'};
      $disco2 = ${$pair{$id}}[1]->{'disco'};
   } else {
      $chr2 = ${$pair{$id}}[0]->{'chr'};
      $coor2 = ${$pair{$id}}[0]->{'coor'};
      $bp2 = $chr2."\t".$coor2;
      $support2 = ${$pair{$id}}[0]->{'su'};
      $pw2 = ${$pair{$id}}[0]->{'pw'};
      $ct2 = ${$pair{$id}}[0]->{'ct'};
      $repornot2 = ${$pair{$id}}[0]->{'rep'};
      $disco2 = ${$pair{$id}}[0]->{'disco'};
   }
   $count2 = $redundancy{$bp2}{'count'};

   my $supportA = $support + $support2;
   my $pwA = $pw + $pw2;

   next if ($repornot eq 'R');                        #now it is not repeat
   next if ($chr eq 'chrM' or $chr2 eq 'chrM');       #now it is not chrM
   #next if ($support < 3 and $pw < 5 and $ct == 0);   #now support is at least 3

   if (! exists($forget{$id})) {

     print "$remember{$id}" if (! exists $printed{$id} );
     $printed{$id} = '';

   } else { #it is forgot, SAVE SAVE SAVE

       if ( $disco >= 3 and $single{$bp}{'id'} ne '' ) {

          my $idS = $single{$bp}{'id'};

          if (exists ($forget{$idS})) {
             next if ($single{$bp}{'su'} < 5 or $single{$bp}{'pw'} < 3);
             next if $single{$bp}{'rep'} eq 'R';
          }
          #now the rest single bps must be better than 5,3 thresholds

          print "$remember{$idS}" if (! exists $printed{$idS} );
          $printed{$idS} = '';

       } elsif ( $ct > 0 and $ct2 > 0 ) {
          unless ($repornot2 eq 'R' and $support == 1) {
            print "$remember{$id}" if (! exists $printed{$id} );
            $printed{$id} = '';
          }
       }

   } #it is forgotted
}


exit 0;

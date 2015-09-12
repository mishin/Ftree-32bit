#line 1 "Log/Log4perl/Config/DOMConfigurator.pm"
package Log::Log4perl::Config::DOMConfigurator;
use Log::Log4perl::Config::BaseConfigurator;

our @ISA = qw(Log::Log4perl::Config::BaseConfigurator);

#todo
# DONE(param-text) some params not attrs but values, like <sql>...</sql>
# DONE see DEBUG!!!  below
# NO, (really is only used for AsyncAppender) appender-ref in <appender>
# DONE check multiple appenders in a category
# DONE in Config.pm re URL loading, steal from XML::DOM
# DONE, OK see PropConfigurator re importing unlog4j, eval_if_perl
# NO (is specified in DTD) - need to handle 0/1, true/false?
# DONE see Config, need to check version of XML::DOM
# OK user defined levels? see parse_level
# OK make sure 2nd test is using log4perl constructs, not log4j
# OK handle new filter stuff
# make sure sample code actually works
# try removing namespace prefixes in the xml

use XML::DOM;
use Log::Log4perl::Level;
use strict;

use constant _INTERNAL_DEBUG => 0;

our $VERSION = 0.03;

our $APPENDER_TAG = qr/^((log4j|log4perl):)?appender$/;

our $FILTER_TAG = qr/^(log4perl:)?filter$/;
our $FILTER_REF_TAG = qr/^(log4perl:)?filter-ref$/;

#can't use ValParser here because we're using namespaces? 
#doesn't seem to work - kg 3/2003 
our $PARSER_CLASS = 'XML::DOM::Parser';

our $LOG4J_PREFIX = 'log4j';
our $LOG4PERL_PREFIX = 'log4perl';
    

#poor man's export
*eval_if_perl = \&Log::Log4perl::Config::eval_if_perl;
*unlog4j      = \&Log::Log4perl::Config::unlog4j;


###################################################
sub parse {
###################################################
    my($self, $newtext) = @_;

    $self->text($newtext) if defined $newtext;
    my $text = $self->{text};

    my $parser = $PARSER_CLASS->new;
    my $doc = $parser->parse (join('',@$text));


    my $l4p_tree = {};
    
    my $config = $doc->getElementsByTagName("$LOG4J_PREFIX:configuration")->item(0)||
                 $doc->getElementsByTagName("$LOG4PERL_PREFIX:configuration")->item(0);

    my $threshold = uc(subst($config->getAttribute('threshold')));
    if ($threshold) {
        $l4p_tree->{threshold}{value} = $threshold;
    }

    if (subst($config->getAttribute('oneMessagePerAppender')) eq 'true') {
        $l4p_tree->{oneMessagePerAppender}{value} = 1;
    }

    for my $kid ($config->getChildNodes){

        next unless $kid->getNodeType == ELEMENT_NODE;

        my $tag_name = $kid->getTagName;

        if ($tag_name =~ $APPENDER_TAG) {
            &parse_appender($l4p_tree, $kid);

        }elsif ($tag_name eq 'category' || $tag_name eq 'logger'){
            &parse_category($l4p_tree, $kid);
            #Treating them the same is not entirely accurate, 
            #the dtd says 'logger' doesn't accept
            #a 'class' attribute while 'category' does.
            #But that's ok, log4perl doesn't do anything with that attribute

        }elsif ($tag_name eq 'root'){
            &parse_root($l4p_tree, $kid);

        }elsif ($tag_name =~ $FILTER_TAG){
            #parse log4perl's chainable boolean filters
            &parse_l4p_filter($l4p_tree, $kid);

        }elsif ($tag_name eq 'renderer'){
            warn "Log4perl: ignoring renderer tag in config, unimplemented";
            #"log4j will render the content of the log message according to 
            # user specified criteria. For example, if you frequently need 
            # to log Oranges, an object type used in your current project, 
            # then you can register an OrangeRenderer that will be invoked 
            # whenever an orange needs to be logged. "
         
        }elsif ($tag_name eq 'PatternLayout'){#log4perl only
            &parse_patternlayout($l4p_tree, $kid);
        }
    }
    $doc->dispose;

    return $l4p_tree;
}

#this is just for toplevel log4perl.PatternLayout tags
#holding the custom cspecs
sub parse_patternlayout {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $name = subst($child->getAttribute('name'));
        my $value;

        foreach my $grandkid ($child->getChildNodes){
            if ($grandkid->getNodeType == TEXT_NODE) {
                $value .= $grandkid->getData;
            }
        }
        $value =~ s/^ +//;  #just to make the unit tests pass
        $value =~ s/ +$//;
        $l4p_branch->{$name}{value} = subst($value);
    }
    $l4p_tree->{PatternLayout}{cspec} = $l4p_branch;
}


#for parsing the root logger, if any
sub parse_root {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    &parse_children_of_logger_element($l4p_branch, $node);

    $l4p_tree->{category}{value} = $l4p_branch->{value};

}


#this parses a custom log4perl-specific filter set up under
#the root element, as opposed to children of the appenders
sub parse_l4p_filter {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    my $name = subst($node->getAttribute('name'));

    my $class = subst($node->getAttribute('class'));
    my $value = subst($node->getAttribute('value'));

    if ($class && $value) {
        die "Log4perl: only one of class or value allowed, not both, "
            ."in XMLConfig filter '$name'";
    }elsif ($class || $value){
        $l4p_branch->{value} = ($value || $class);

    }

    for my $child ($node->getChildNodes) {

        if ($child->getNodeType == ELEMENT_NODE){

            my $tag_name = $child->getTagName();

            if ($tag_name =~ /^(param|param-nested|param-text)$/) {
                &parse_any_param($l4p_branch, $child);
            }
        }elsif ($child->getNodeType == TEXT_NODE){
            my $text = $child->getData;
            next unless $text =~ /\S/;
            if ($class && $value) {
                die "Log4perl: only one of class, value or PCDATA allowed, "
                    ."in XMLConfig filter '$name'";
            }
            $l4p_branch->{value} .= subst($text); 
        }
    }

    $l4p_tree->{filter}{$name} = $l4p_branch;
}

   
#for parsing a category/logger element
sub parse_category {
    my ($l4p_tree, $node) = @_;

    my $name = subst($node->getAttribute('name'));

    $l4p_tree->{category} ||= {};
 
    my $ptr = $l4p_tree->{category};

    for my $part (split /\.|::/, $name) {
        $ptr->{$part} = {} unless exists $ptr->{$part};
        $ptr = $ptr->{$part};
    }

    my $l4p_branch = $ptr;

    my $class = subst($node->getAttribute('class'));
    $class                       && 
       $class ne 'Log::Log4perl' &&
       $class ne 'org.apache.log4j.Logger' &&
       warn "setting category $name to class $class ignored, only Log::Log4perl implemented";

    #this is kind of funky, additivity has its own spot in the tree
    my $additivity = subst(subst($node->getAttribute('additivity')));
    if (length $additivity > 0) {
        $l4p_tree->{additivity} ||= {};
        my $add_ptr = $l4p_tree->{additivity};

        for my $part (split /\.|::/, $name) {
            $add_ptr->{$part} = {} unless exists $add_ptr->{$part};
            $add_ptr = $add_ptr->{$part};
        }
        $add_ptr->{value} = &parse_boolean($additivity);
    }

    &parse_children_of_logger_element($l4p_branch, $node);
}

# parses the children of a category element
sub parse_children_of_logger_element {
    my ($l4p_branch, $node) = @_;

    my (@appenders, $priority);

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;
            
        my $tag_name = $child->getTagName();

        if ($tag_name eq 'param') {
            my $name = subst($child->getAttribute('name'));
            my $value = subst($child->getAttribute('value'));
            if ($value =~ /^(all|debug|info|warn|error|fatal|off|null)^/) {
                $value = uc $value;
            }
            $l4p_branch->{$name} = {value => $value};
        
        }elsif ($tag_name eq 'appender-ref'){
            push @appenders, subst($child->getAttribute('ref'));
            
        }elsif ($tag_name eq 'level' || $tag_name eq 'priority'){
            $priority = &parse_level($child);
        }
    }
    $l4p_branch->{value} = $priority.', '.join(',', @appenders);
    
    return;
}


sub parse_level {
    my $node = shift;

    my $level = uc (subst($node->getAttribute('value')));

    die "Log4perl: invalid level in config: $level"
        unless Log::Log4perl::Level::is_valid($level);

    return $level;
}



sub parse_appender {
    my ($l4p_tree, $node) = @_;

    my $name = subst($node->getAttribute("name"));

    my $l4p_branch = {};

    my $class = subst($node->getAttribute("class"));

    $l4p_branch->{value} = $class;

    print "looking at $name----------------------\n"  if _INTERNAL_DEBUG;

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        my $name = unlog4j(subst($child->getAttribute('name')));

        if ($tag_name =~ /^(param|param-nested|param-text)$/) {

            &parse_any_param($l4p_branch, $child);

            my $value;

        }elsif ($tag_name =~ /($LOG4PERL_PREFIX:)?layout/){
            $l4p_branch->{layout} = parse_layout($child);

        }elsif ($tag_name =~  $FILTER_TAG){
            $l4p_branch->{Filter} = parse_filter($child);

        }elsif ($tag_name =~ $FILTER_REF_TAG){
            $l4p_branch->{Filter} = parse_filter_ref($child);

        }elsif ($tag_name eq 'errorHandler'){
            die "errorHandlers not supported yet";

        }elsif ($tag_name eq 'appender-ref'){
            #dtd: Appenders may also reference (or include) other appenders. 
            #This feature in log4j is only for appenders who implement the 
            #AppenderAttachable interface, and the only one that does that
            #is the AsyncAppender, which writes logs in a separate thread.
            #I don't see the need to support this on the perl side any 
            #time soon.  --kg 3/2003
            die "Log4perl: in config file, <appender-ref> tag is unsupported in <appender>";
        }else{
            die "Log4perl: in config file, <$tag_name> is unsupported\n";
        }
    }
    $l4p_tree->{appender}{$name} = $l4p_branch;
}

sub parse_any_param {
    my ($l4p_branch, $child) = @_;

    my $tag_name = $child->getTagName();
    my $name = subst($child->getAttribute('name'));
    my $value;

    print "parse_any_param: <$tag_name name=$name\n" if _INTERNAL_DEBUG;

    #<param-nested>
    #note we don't set it to { value => $value }
    #and we don't test for multiple values
    if ($tag_name eq 'param-nested'){
        
        if ($l4p_branch->{$name}){
            die "Log4perl: in config file, multiple param-nested tags for $name not supported";
        }
        $l4p_branch->{$name} = &parse_param_nested($child); 

        return;

    #<param>
    }elsif ($tag_name eq 'param') {

         $value = subst($child->getAttribute('value'));

         print "parse_param_nested: got param $name = $value\n"  
             if _INTERNAL_DEBUG;
        
         if ($value =~ /^(all|debug|info|warn|error|fatal|off|null)$/) {
             $value = uc $value;
         }

         if ($name !~ /warp_message|filter/ &&
            $child->getParentNode->getAttribute('name') ne 'cspec') {
            $value = eval_if_perl($value);
         }
    #<param-text>
    }elsif ($tag_name eq 'param-text'){

        foreach my $grandkid ($child->getChildNodes){
            if ($grandkid->getNodeType == TEXT_NODE) {
                $value .= $grandkid->getData;
            }
        }
        if ($name !~ /warp_message|filter/ &&
            $child->getParentNode->getAttribute('name') ne 'cspec') {
            $value = eval_if_perl($value);
        }
    }

    $value = subst($value);

     #multiple values for the same param name
     if (defined $l4p_branch->{$name}{value} ) {
         if (ref $l4p_branch->{$name}{value} ne 'ARRAY'){
             my $temp = $l4p_branch->{$name}{value};
             $l4p_branch->{$name}{value} = [$temp];
         }
         push @{$l4p_branch->{$name}{value}}, $value;
     }else{
         $l4p_branch->{$name} = {value => $value};
     }
}

#handles an appender's <param-nested> elements
sub parse_param_nested {
    my ($node) = shift;

    my $l4p_branch = {};

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        if ($tag_name =~ /^param|param-nested|param-text$/) {
            &parse_any_param($l4p_branch, $child);
        }
    }

    return $l4p_branch;
}

#this handles filters that are children of appenders, as opposed
#to the custom filters that go under the root element
sub parse_filter {
    my $node = shift;

    my $filter_tree = {};

    my $class_name = subst($node->getAttribute('class'));

    $filter_tree->{value} = $class_name;

    print "\tparsing filter on class $class_name\n"  if _INTERNAL_DEBUG;  

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        if ($tag_name =~ 'param|param-nested|param-text') {
            &parse_any_param($filter_tree, $child);
        
        }else{
            die "Log4perl: don't know what to do with a ".$child->getTagName()
                ."inside a filter element";
        }
    }
    return $filter_tree;
}

sub parse_filter_ref {
    my $node = shift;

    my $filter_tree = {};

    my $filter_id = subst($node->getAttribute('id'));

    $filter_tree->{value} = $filter_id;

    return $filter_tree;
}



sub parse_layout {
    my $node = shift;

    my $layout_tree = {};

    my $class_name = subst($node->getAttribute('class'));
    
    $layout_tree->{value} = $class_name;
    #
    print "\tparsing layout $class_name\n"  if _INTERNAL_DEBUG;  
    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;
        if ($child->getTagName() eq 'param') {
            my $name = subst($child->getAttribute('name'));
            my $value = subst($child->getAttribute('value'));
            if ($value =~ /^(all|debug|info|warn|error|fatal|off|null)$/) {
                $value = uc $value;
            }
            print "\tparse_layout: got param $name = $value\n"
                if _INTERNAL_DEBUG;
            $layout_tree->{$name}{value} = $value;  

        }elsif ($child->getTagName() eq 'cspec') {
            my $name = subst($child->getAttribute('name'));
            my $value;
            foreach my $grandkid ($child->getChildNodes){
                if ($grandkid->getNodeType == TEXT_NODE) {
                    $value .= $grandkid->getData;
                }
            }
            $value =~ s/^ +//;
            $value =~ s/ +$//;
            $layout_tree->{cspec}{$name}{value} = subst($value);  
        }
    }
    return $layout_tree;
}

sub parse_boolean {
    my $a = shift;

    if ($a eq '0' || lc $a eq 'false') {
        return '0';
    }elsif ($a eq '1' || lc $a eq 'true'){
        return '1';
    }else{
        return $a; #probably an error, punt
    }
}


#this handles variable substitution
sub subst {
    my $val = shift;

    $val =~ s/\$\{(.*?)}/
                      Log::Log4perl::Config::var_subst($1, {})/gex;
    return $val;
}

1;

__END__



#line 913

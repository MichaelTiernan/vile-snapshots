# $Header: /users/source/archives/vile.vcs/filters/RCS/mk-1st.awk,v 1.6 2000/07/26 23:53:12 tom Exp $
#
# Generate makefile lists for vile's external and built-in filters.  We will
# build each filter only one way (external _or_ built-in).  This script uses
# these parameters:
#	mode =	'built-in' or 'external'
#	list =	a list of the filter root-names that are built-in, with 'all'
#		matching all root-names.
function dump_list(format, name, names, only) {
	printf "%s =", name
	for (i = 0; i < count; i++) {
		if (index(file[i], only)) {
			printf " \\\n\t"
			printf format, names[i]
		}
	}
	print ""
	print ""
}
BEGIN	{
		first = 1;
		count = 0;
	}
	!/^#/ {
		# command-line parameters aren't available until we're matching
		if (first == 1) {
			Len = split(list,List,/,/)
			Opt = (mode == "built-in");
		}
		found = !Opt;
		if ( NF >= 2 ) {
			for (i = 1; i <= Len; i++) {
				if ( $1 == List[i] || List[i] == "all" ) {
					found = Opt;
					break;
				}
			}
			if (found) {
				if ( NF > 3 )
					prog[count] = $4 "$x";
				else
					prog[count] = "vile-" $1 "-filt$x";
				file[count] = sprintf("%s.%s", $2, $3);
				root[count] = $2;
				count = count + 1;
			}
			if ((first == 1) && (found == Opt)) {
				printf "# Lists generated by filters/mk-1st.awk for %s filters\n", mode
				first = 0;
			}
		}
	}
END	{
		if ( !Opt ) {
			dump_list("%s", "C_ALL", prog, ".c");
			dump_list("%s", "LEX_ALL", prog, ".l");
			dump_list("$(BINDIR)/%s", "INSTALL_C", prog, ".c");
			dump_list("$(BINDIR)/%s", "INSTALL_LEX", prog, ".l");
		} else {
			dump_list("%s$o", "C_OBJ", root, ".c");
			dump_list("%s$o", "LEX_OBJ", root, ".l");
		}
	}

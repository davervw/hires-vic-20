export ACME=/c/Users/Dave/Downloads/acme0.96.4win/acme 
#export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.3-win32/GTK3VICE-3.3-win32-r35872
#export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.4-win64-r37564
#export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.4-win64-r37568-nocpuhist/GTK3VICE-3.4-win64-r37568
#export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.5-win64/bin
#export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.5-win64-r39860/bin
export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.6.1-win64/bin
#export VICE=/c/Users/Dave/Downloads/SDL2VICE-3.6.1-win64
${ACME}/acme -f cbm -l build/labels -o build/hires20.prg code/hires20.asm
[ $? -eq 0 ] || exit 1
bin/win/prgsize build/hires20.prg > build/size.dat
[ $? -eq 0 ] && cat build/loaderbasic.prg build/loaderml.prg build/size.dat build/hires20.prg > build/loadhires20.prg
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach build/hires20.d64
delete loadhires20
delete license
delete hires20.asm
delete hires20.ml
write build/loadhires20.prg "loadhires20"
write LICENSE license,s
write code/hires20.asm hires20.asm,s
write build/hires20.prg hires20.ml
EOF
[ $? -eq 0 ] && ${VICE}/xvic.exe -moncommands build/labels build/hires20.d64
rm vic20_files/*
cd vic20_files
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach ../build/hires20.d64
extract
EOF
cd ..
pwd
#! /bin/sh - 

# Escrito por Arthur Félix dos Santos Grassi - 3S QSS BCO
# Recife, 05 de abril de 2024

raiz=$(readlink -f $(dirname $0))
title="Etapas CSV"

oficio=$( zenity --entry --title "$title" --text "Entre com o número do ofício: " --window-icon "$raiz/etapas-csv.png" )
if [ -z "$oficio" ]
then
    zenity --error --title "$title" --text "Nenhum número de ofício foi fornecido."
    exit 1
fi

header='**NR_ORDEM**;MÊS;ANO;LEGISLAÇÃO EM VIGOR;LTR;DIAS DE CONCESSÃO DO AUXÍLIO ALIMENTAÇÃO;LTR1;DIAS DO MÊS DE CONCESSÃO DO AUXÍLIO ALIMENTAÇÃO;LT2;NÚMERO DE DIAS;LTR3;DIAS DE CONCESSÃO DO AUXÍLIO ALIMENTAÇÃO(LTR3)'
amparo='letra “e” do inciso I do art. 2º e inciso XIII do art. 3º da Medida Provisória nº 2.215-10, de 31/08/2001, art. 66, inciso II do art. 67, caput e § 1º do art. 71 e art. 73 do Decreto nº 4.307, de 18/07/2002, parágrafo único do art. 2º, incisos I e II do art. 4º da Portaria nº 359/GC4, de 06/04/2016 (MILITAR DO CINDACTA III). Número Ofício: '"$oficio"

sgpo () {
    FILE=`zenity  --title "Escolha o PDF do SGPO: " --filename="$HOME/" --file-selection --file-filter "*.pdf"`
    if [ -z "$FILE" ]
    then
        zenity --error --title "$title" --text "Nenhum arquivo PDF foi escolhido."
        exit 1
    fi

    pdftops "$FILE"
    arquivo=$( echo "$FILE" | sed 's/\.pdf/.ps/' )

    if ! grep '(RELAT\\323RIO DE EXPOSI\\307\\303O PARA AUX\\315LIO-ALIMENTA\\307\\303\\' "$arquivo" > /dev/null
    then
        rm "$arquivo"
        zenity --error --title "$title" --text "PDF inválido!"
        exit 1
    fi

    de=''

    case "$1" in
        "re")
            de="ACC-RE DE"
        ;;

        "ao")
            de="ACC-AO DE"
        ;;

        "wf")
            de="APP-RF DE"
        ;;
    esac

    echo "$de"
    mes=$( grep "$de" "$arquivo" | head -n1 | sed 's/)$//' | cut -d' ' -f5 | sed 's/MAR\\347O/MARÇO/g' )
    ano=$( grep "$de" "$arquivo" | head -n1 | sed 's/)$//' | cut -d' ' -f7 )

    echo "Mês: $mes"
    echo "Ano: $ano"
    
    if [ -z "$mes" ] || [ -z "$ano" ] 
    then 
        zenity --error --title "$title" --text "Órgão operacional incorreto. \nVerifique o documento ou o órgão selecionado. "
        exit 1
    fi 

    if grep -q "24H)" "$arquivo" # se arquivo novo
    then # então, filtro novo
        grep '^([^()]*)$' "$arquivo" | 
            sed -e 's/^(//' -e 's/)$//' | 
                sed -e '/MINIST/,/SOMA/d' -e '/ASS\. Comandante/d' -e 's/^[0-9]\{5,\}$/\n&/' | 
                    tr '\n' '@' | 
                        sed -e 's/@@/\n/g' -e 's/^@//' -e 's/@$/\n/' | 
        while read linha
        do
            saram=$(echo "$linha" | cut -d'@' -f1)

            ltr3=$(echo "$linha" | grep -oE "@<= 08H@([0-9]{1,},* *){1,},*@" | sed 's/.*H@\([^@]*\)@/\1/')
            echo "$ltr3" | grep -q ', *$' && ltr3=$(echo "$linha" | grep -oE "@<= 08H@([0-9]{1,},* *){1,}, *@[^@]*@" | sed 's/.*H@\([^@]*\)@\([^@]*\)@/\1 \2/') 
            
            if [ "X$ltr3" = "X0" ]
            then 
                ltr3=''
                ltr3x=''
            elif [ -n "$ltr" ] 
            then 
                ltr3x='X' 
            fi
            
            ltr=$(echo "$linha" | grep -oE "@> 08H <( *|@)24H@([0-9]{1,},* *){1,},*@" | sed 's/.*24H@\([^@]*\)@/\1/')
            echo "$ltr" | grep -q ', *$' && ltr=$(echo "$linha" | grep -oE "@> 08H <( *|@)24H@([0-9]{1,},* *){1,}, *@[^@]*@" | sed 's/.*H@\([^@]*\)@\([^@]*\)@/\1 \2/') 
            
            if [ "X$ltr" = "X0" ]
            then 
                ltr=''
                ltrx=''
            elif [ -n "$ltr" ] 
            then 
                ltrx='X' 
            fi
            
            echo "$saram;$mes;$ano;$amparo;$ltrx;$ltr;;;X;0;$ltr3x;$ltr3" >> saida
        done
    else # senão, filtro antigo para o arquivo antigo
        grep '^([^()]*)$' "$arquivo" | 
        sed -e 's/^(//' -e 's/)$//' | 
            tr '\n' '@' | 
                sed -e 's/@ASS/@&/g' -e 's/@[0-9][0-9][0-9][0-9]*/@&/g' | 
                    tr '@' '\n' | 
                        sed -e 's/$/@/' -e 's/^@$//' | 
                            tr '\n' '@' | 
                                sed -e 's/@@@/\n/g' -e 's/@@/@/g' -e 's/, *@/, /g' | 
                                    grep -vE '(MINIST\\|Chefe)' | 
        while read line
        do 
            if echo $line | grep '<= 08H@0' > /dev/null
            then
                echo $line | while IFS='@' read saram posto nome t3 td3 td tr ltr tdr
                do
                    ltrx='X'
                    lt3x=
                    lt3=
                    ltr=$( echo $ltr | sed 's/ //g' )
                    echo "$saram;$mes;$ano;$amparo;$ltrx;$ltr;;;X;0;$lt3x;$lt3" >> saida
                done
            elif echo $line | grep '> 08H@0' > /dev/null
            then 
                echo $line | while IFS='@' read saram posto nome t3 lt3 td3 td tr tdr
                do
                    ltrx=
                    lt3x='X'
                    ltr=
                    lt3=$( echo $lt3 | sed 's/ //g' )
                    echo "$saram;$mes;$ano;$amparo;$ltrx;$ltr;;;X;0;$lt3x;$lt3" >> saida
                done
            else 
                echo $line | while IFS='@' read saram posto nome t3 lt3 td3 td tr ltr tdr
                do
                    ltrx='X'
                    lt3x='X'
                    lt3=$( echo $lt3 | sed 's/ //g' )
                    ltr=$( echo $ltr | sed 's/ //g' )
                    echo "$saram;$mes;$ano;$amparo;$ltrx;$ltr;;;X;0;$lt3x;$lt3" >> saida
                done
            fi 
        done 
    fi 

    produto=$( echo $arquivo | sed 's#.*/\([^/]*\)\.ps#\1.csv#' )
    rm "$arquivo"
}

fis () {
    arquivo=`zenity  --title "Escolha o CSV do GEOP: " --filename="$HOME/" --file-selection --file-filter "*.csv"`
    if [ -z "$arquivo" ]
    then
        zenity --error --title "$title" --text "Nenhum arquivo CSV foi escolhido."
        exit 1
    fi

    mes=$( cal -m `echo $arquivo | sed 's/.*_\([0-9]*\)-[0-9]*.*$/\1/'` | head -n1 | sed -e 's/ *\([A-Za-z][a-z]*\) [0-9]*/\U\1/' -e 's/ *//g' )
    if [ -z "$mes" ]
    then
        zenity --error --title "$title" --text "CSV inválido!"
        exit 1
    fi
    
    ano=$( echo $arquivo | sed 's/.*_[0-9]*-\([0-9]*\).*$/\1/' )

    tail -n +2 "$arquivo" | while IFS=';' read posto quadro esp nome apelido saram lt3 ltr a b c d e 
    do
        if echo $lt3 | grep '(0)' > /dev/null 
        then 
            lt3x=
            lt3=
        else
            lt3x='X'
            lt3=$( echo $lt3 | sed 's#"([0-9]*)/\([0-9,]*\)"#\1#' )
        fi

        if echo $ltr | grep '(0)' > /dev/null 
        then 
            ltrx=
            ltr=
        else
            ltrx='X'
            ltr=$( echo $ltr | sed 's#"([0-9]*)/\([0-9,]*\)"#\1#' )
        fi
        
        echo "$saram;$mes;$ano;$amparo;$ltrx;$ltr;;;X;0;$lt3x;$lt3" >> saida
    done 

    produto=$( echo $arquivo | sed 's#.*/\([^/]*\)\(\.csv\)#\1.PORTAL-DA-OM\2#' )
}

cd "$raiz"

orgao=$( zenity --list --radiolist --title "$title" --text "Escolha o órgão operacional: "  --hide-header --column "Seleciona" --column "Itens" FALSE "ACC-RE" FALSE "ACC-AO" FALSE "APP-RF" FALSE "FIS" )

case "$orgao" in 
    "ACC-RE")
        sgpo re
    ;;

    "ACC-AO")
        sgpo ao
    ;;

    "APP-RF")
        sgpo wf
    ;;

    "FIS")
        fis
    ;;

    *)
        zenity --error --title "$title" --text "Nenhum órgão operacional foi escolhido."
        exit 1
    ;;
esac

sed -i "1i $header" saida
desktop=$( xdg-user-dir DESKTOP )

salvo=`zenity --file-selection --save --title="Salvando o arquivo..."  --filename="$desktop/$produto" --confirm-overwrite --file-filter "*.csv"`
if [ -z "$salvo" ]
then 
    rm saida
    zenity --error --title "$title" --text "O arquivo não foi salvo."
    exit 1
fi 

mv saida "$salvo"
sort -t';' -k1n "$salvo" -o "$salvo"

if zenity --question --title "$title" --text "Deseja abrir o arquivo salvo?"
then 
    gedit "$salvo"
else
    zenity --info --title "$title" --window-icon=etapas-csv.png --text "Safo!"
fi

exit 0

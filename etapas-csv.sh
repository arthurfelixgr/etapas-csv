#! /bin/bash -

# Escrito por Arthur Félix dos Santos Grassi - 3S QSS BCO
# Recife, 20 de julho de 2025


raiz=$(readlink -f $(dirname $0))
title="Etapas CSV"

oficio=$( zenity --entry --title "$title" --text "Entre com o número do ofício: " --window-icon "$raiz/etapas-csv.png" )
if [ -z "$oficio" ]
then
    zenity --error --title "$title" --text "Nenhum número de ofício foi fornecido."
    exit 1
fi

amparo='letra “e” do inciso I do art. 2º e inciso XIII do art. 3º da Medida Provisória nº 2.215-10, de 31/08/2001, art. 66, inciso II do art. 67, caput e § 1º do art. 71 e art. 73 do Decreto nº 4.307, de 18/07/2002, parágrafo único do art. 2º, incisos I e II do art. 4º da Portaria nº 359/GC4, de 06/04/2016 (MILITAR DO CINDACTA III). Número Ofício: '"$oficio"

if ! editaAmparo=$(echo "$amparo" | zenity --text-info --title "Confirme o amparo: "  --ok-label Confirmar --extra-button Editar)
then
    if [ "$editaAmparo" == "Editar" ]
    then
        if ! amparo=$(echo "$amparo" | zenity --text-info --title "Confirme o amparo: "  --editable)
        then
            zenity --error --title "$title" --text "Amparo normativo não confirmado."
            exit 1
        fi
    else
        zenity --error --title "$title" --text "Amparo normativo não confirmado."
        exit 1
    fi
fi

amparo=$(echo "$amparo" | tr '\n' '@' | sed 's/@//g')

header='**NR_ORDEM**;MÊS;ANO;LEGISLAÇÃO EM VIGOR;LTR;DIAS DE CONCESSÃO DO AUXÍLIO ALIMENTAÇÃO;LTR1;DIAS DO MÊS DE CONCESSÃO DO AUXÍLIO ALIMENTAÇÃO;LT2;NÚMERO DE DIAS;LTR3;DIAS DE CONCESSÃO DO AUXÍLIO ALIMENTAÇÃO(LTR3)'

sgpo() {
    FILE=`zenity  --title "Escolha o PDF do SGPO: " --filename="$HOME/" --file-selection --file-filter "*.pdf"`
    if [ -z "$FILE" ]
    then
        zenity --error --title "$title" --text "Nenhum arquivo PDF foi escolhido."
        exit 1
    fi
    
    pdftohtml -c -i -s "$FILE"
    
    (
    arquivo=$( echo "$FILE" | sed 's/\.pdf/-html.html/' )
    sed -i -E 's/(&#160;)+/ /g' "$arquivo"
    if ! grep -q 'RELATÓRIO DE EXPOSIÇÃO PARA AUXÍLIO-ALIMENTAÇÃO' "$arquivo"
    then
        rm "$arquivo"
        zenity --error --title "$title" --text "PDF inválido!"
        exit 1
    fi
    
    titulo=$(grep 'RELATÓRIO DE EXPOSIÇÃO PARA AUXÍLIO-ALIMENTAÇÃO' "$arquivo" | head -n1 | sed -E 's/<[^>]*>//g')
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

        "rf")
            de="TWR-RF DE"
        ;;

        "wk")
            de="APP-PS DE"
        ;;

        "ps")
            de="TWR-PS DE"
        ;;
    esac
    
    if ! echo "$titulo" | grep -q "$de"
    then 
        zenity --error --title "$title" --text "Órgão operacional incorreto. \nVerifique o documento ou o órgão selecionado. "
        exit 1
    fi
    
    IFS=' ' read -a tituloArray <<< "$titulo"
    mes="${tituloArray[-3]}"
    ano="${tituloArray[-1]}"

    echo "Mês: $mes"
    echo "Ano: $ano" 

    cat "$arquivo" |
      sed -e 's/<[^>]*>//g' \
      -e 's/&gt;/>/g' \
      -e 's/&lt;/</g' \
      -e '/^[[:space:]]*$/d' \
      -e '/<!--/,/-->/d' \
      -Ee 's/(^[[:space:]]*|[[:space:]]*$)//g' \
      -e '/(\.html$|A[sS]{2}\.*.*[cC].* OM$)/d' \
      -e '/^MINIST.*RIO DA DEFESA$/,/^SOMA$/d' -e 's/^([0-9]{6,})/\n\1/' |
        tr '\n' '@' |
          sed -e 's/^@//' -e 's/@@/@\n/g' |
            sed -e 's/^/{"saram":/' \
            -e 's/@/, "posto":/' \
            -Ee 's/(, "posto":[^@]+)@/\1, "nome":/' \
            -e 's/([^@]+)@([^@]+)(@> 08H <[@ ]*24H@)/, "total-simples":\1, "total":\2\3/' \
            -e 's/([^@]+)(@>= 24H@)/, "total-cheia":\1\2/' \
            -e 's/[^@]+@$/, "total-maior":&/' \
            -e 's/@$/}/' \
            -e 's/@<= 08H@/, "dias-simples":/' \
            -e 's/@> 08H <[@ ]*24H@/, "dias-cheia":/' \
            -e 's/@>= 24H@/, "dias-maior":/' \
            -e 's/@/ /g' \
            -e 's/ , "/, "/g' \
            -e 's/":,/":"",/g' |
              sed -Ee 's/(^\{|\}$)//g' \
              -Ee 's/, "[^"]+":/@/g' \
              -Ee 's/^"[^"]+"://' -e 's/""//g' | 
                awk -v mes="$mes" -v ano="$ano" -v amparo="$amparo" -F'@' '{ 
                  saram = $1; 
                  posto = $2; 
                  nome = $3; 
                  diasLtr3 = $4; 
                  totalLtr3 = $5; 
                  total = $6; 
                  diasLtr = $7; 
                  totalLtr = $8; 
                  diasLtr1 = $9; 
                  totalLtr1 = $10; 
                  ltrX = totalLtr > 0 ? "X" : "";
                  ltr3X = totalLtr3 > 0 ? "X" : "";
                  printf "%s;%s;%s;%s;%s;%s;;;X;0;%s;%s\n", saram, mes, ano, amparo, ltrX, diasLtr, ltr3X, diasLtr3 
                }' > saida
    
    rm "$arquivo"
    echo "\n"
    ) | zenity --progress --text="Por favor, aguarde... " --pulsate --auto-close
    
    produto=$( echo "$FILE" | sed -E 's/.*\/([^/]*)\.pdf$/\1.csv/' )
}

geop() {
    arquivo=`zenity  --title "Escolha o CSV do GEOP: " --filename="$HOME/" --file-selection --file-filter "*.csv"`
    if [ -z "$arquivo" ]
    then
        zenity --error --title "$title" --text "Nenhum arquivo CSV foi escolhido."
        exit 1
    fi

    (
    nmes=$(echo "$arquivo" | sed 's/.*_\([0-9]*\)-[0-9]*.*$/\1/')
    if [ -z "$nmes" ]
    then
        zenity --error --title "$title" --text "CSV inválido!"
        exit 1
    fi

    case $nmes in
        1)
	        mes="JANEIRO"
	    ;;
        2)
	        mes="FEVEREIRO"
	    ;;
        3)
	        mes="MARÇO"
	    ;;
        4)
	        mes="ABRIL"
	    ;;
        5)
	        mes="MAIO"
	    ;;
        6)
	        mes="JUNHO"
	    ;;
        7)
	        mes="JULHO"
	    ;;
        8)
	        mes="AGOSTO"
	    ;;
        9)
	        mes="SETEMBRO"
	    ;;
        10)
	        mes="OUTUBRO"
	    ;;
        11)
	        mes="NOVEMBRO"
	    ;;
        12)
	        mes="DEZEMBRO"
	    ;;
        *)
	        zenity --error --title "$title" --text "CSV inválido!"
	        exit 1
	    ;;
    esac
    	
    
    ano=$( echo $arquivo | sed 's/.*_[0-9]*-\([0-9]*\).*$/\1/' )

    tail -n +2 "$arquivo" | while IFS=';' read posto quadro esp nome apelido saram lt3 ltr a b c d e 
    do
        if echo $lt3 | grep -q '(0)' 
        then 
            lt3x=
            lt3=
        else
            lt3x='X'
            lt3=$( echo $lt3 | sed 's#"([0-9]*)/\([0-9,]*\)"#\1#' )
        fi

        if echo $ltr | grep -q '(0)' 
        then 
            ltrx=
            ltr=
        else
            ltrx='X'
            ltr=$( echo $ltr | sed 's#"([0-9]*)/\([0-9,]*\)"#\1#' )
        fi
        
        echo "$saram;$mes;$ano;$amparo;$ltrx;$ltr;;;X;0;$lt3x;$lt3" >> saida
    done 
    
    echo "\n"
    ) | zenity --progress --text="Por favor, aguarde... " --pulsate --auto-close
    
    produto=$( echo $arquivo | sed 's#.*/\([^/]*\)\(\.csv\)#\1.PORTAL-DA-OM\2#' )
}

# AQUI COMEÇA A AÇÃO

cd "$raiz"

origem=$( zenity --list --radiolist --title "$title" --text "Escolha o sistema de origem: "  --hide-header --column "Seleciona" --column "Itens" FALSE "SGPO" FALSE "GEOP" )

if [ "$origem" == "SGPO" ]
then
    orgao=$( zenity --list --radiolist --title "$title" --text "Escolha o órgão operacional: "  --hide-header --column "Seleciona" --column "Itens" FALSE "ACC-RE" FALSE "ACC-AO" FALSE "APP-RF" FALSE "TWR-RF" FALSE "APP-PS" FALSE "TWR-PS" )
else
    orgao=$origem #geop
fi

#orgao=$( zenity --list --radiolist --title "$title" --text "Escolha o órgão operacional: "  --hide-header --column "Seleciona" --column "Itens" FALSE "ACC-RE" FALSE "ACC-AO" FALSE "APP-RF" FALSE "TWR-RF" FALSE "FIS" FALSE "APP-PS" FALSE "TWR-PS" FALSE "SALVAERO" )

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

    "TWR-RF")
        sgpo rf
    ;;

    "APP-PS")
        sgpo wk
    ;;

    "TWR-PS")
        sgpo ps
    ;;
    
    "GEOP")
        geop
    ;;

    *)
        if [ -z "$origem" ]
        then
            zenity --error --title "$title" --text "Nenhum sistema de origem foi escolhido."
        else
            zenity --error --title "$title" --text "Nenhum órgão operacional foi escolhido."
        fi
        
        exit 1
    ;;
esac

sed -i "1i $header" saida
desktop=$( xdg-user-dir DESKTOP )

salvo=$(zenity --file-selection --save --title="Salvando o arquivo..."  --filename="$desktop/$produto" --confirm-overwrite --file-filter "*.csv")
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

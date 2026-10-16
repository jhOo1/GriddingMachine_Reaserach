\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{chinese}[2026/07/11]




% Load required packages before loading the class
\RequirePackage{CJKutf8}
\RequirePackage{CJKnumb}
\RequirePackage{eso-pic}
\RequirePackage{fancyhdr}
\RequirePackage{graphicx}
\RequirePackage{indentfirst}
\RequirePackage{inputenc}
    \PassOptionsToPackage{utf8}{inputenc}
\RequirePackage{setspace}
\RequirePackage{tikz}
\RequirePackage{xcolor}




% Declare options related to the class
% Font size
\DeclareOption{10pt}{\def\npts\@ptsize{10}}
\DeclareOption{11pt}{\def\npts\@ptsize{11}}
\DeclareOption{12pt}{\def\npts\@ptsize{12}}
\DeclareOption{13pt}{\def\npts\@ptsize{13}}
\DeclareOption{14pt}{\def\npts\@ptsize{14}}
% References type
\DeclareOption{apadoi}{
    \PassOptionsToPackage{round,sort&compress}{natbib}
    \bibliographystyle{apadoi}
}
\DeclareOption{apamaxdoi}{
    \PassOptionsToPackage{round,sort&compress}{natbib}
    \bibliographystyle{apamaxdoi}
}
\DeclareOption{num}{
    \PassOptionsToPackage{numbers,sort&compress,super}{natbib}
    \bibliographystyle{nature}
}
\DeclareOption{numdoi}{
    \PassOptionsToPackage{numbers,square,sort&compress}{natbib}
    \bibliographystyle{numdoi}
}
\DeclareOption{nummaxdoi}{
    \PassOptionsToPackage{numbers,square,sort&compress}{natbib}
    \bibliographystyle{nummaxdoi}
}
% Default options to pass to the article class
\DeclareOption{*}{
    \PassOptionsToClass{\CurrentOption}{article}
}
\ExecuteOptions{12pt}
\ProcessOptions\relax
\PassOptionsToClass{\npts\@ptsize pt}{article}
\LoadClass{article}




% Load required packages after loading the class
\let\CheckCommand\providecommand
\RequirePackage{geometry}
\RequirePackage{natbib}
\RequirePackage{titlesec}
    \titleformat{\section}{\bfseries\normalfont}{\bfseries\thesection}{1em}{\bfseries}
    \titleformat{\subsection}{\bfseries\normalfont}{\bfseries\thesubsection}{1em}{\bfseries}
    \titleformat{\subsubsection}{\bfseries\normalfont}{\bfseries\thesubsubsection}{1em}{\bfseries}
    \titlespacing*{\section}{0pt}{2\baselineskip}{0pt}
    \titlespacing*{\subsection}{0pt}{1\baselineskip}{0pt}
    \titlespacing*{\subsubsection}{0pt}{1\baselineskip}{0pt}




% Page setup
\setlength{\parindent}{2em}




% Notes related
\newcommand{\notesgeometry}{%
    \newgeometry{%
        inner=3cm,%
        outer=6cm,%
        top=3cm,%
        bottom=3cm,%
        marginparwidth=4.5cm,%
        marginparsep=5mm%
    }%
}
\newcommand{\shownotesline}{%
    \AddToShipoutPictureBG{%
        \begin{tikzpicture}[remember picture,overlay]
            \ifodd\value{page}
                \draw[gray!70,dashed,line width=0.4pt]
                ([xshift=\dimexpr1in+\hoffset+\oddsidemargin+\textwidth+0.5\marginparsep\relax]current page.south west)
                --
                ([xshift=\dimexpr1in+\hoffset+\oddsidemargin+\textwidth+0.5\marginparsep\relax]current page.north west);
            \else
                \draw[gray!70,dashed,line width=0.4pt]
                ([xshift=\dimexpr1in+\hoffset+\evensidemargin-0.5\marginparsep\relax]current page.south west)
                --
                ([xshift=\dimexpr1in+\hoffset+\evensidemargin-0.5\marginparsep\relax]current page.north west);
            \fi
        \end{tikzpicture}%
    }%
}
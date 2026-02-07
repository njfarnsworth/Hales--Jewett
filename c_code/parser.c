#include <stdio.h>
#include <stdlib.h>

typedef struct {
    const char *cur; // track pointer to current character
    int line; // track line of file we're on
    int nvars; // number of vars in the CNF file
    int nclauses; // number of clauses in the CNf file
} Parser;

typedef struct {
    int *lits; // integer array
    int size; // size of array 
} Clause;

typedef struct {
    int nvars;
    int nclauses;
    Clause *clauses;
} CNF;

char *load_file(const char *path){
    // a function that loads in the DIMACS CNF file and writes it to a contiguous block of memory
    FILE *f = fopen(path, "rb"); // open the file, and read it in binary mode
    if (!f) return NULL;

    if (fseek(f, 0, SEEK_END) != 0){ // move the pointer to the end of the file. if it fails for some reason, exit
        fclose(f);
        return NULL;
    }
    
    long size = ftell(f); // calculates the offset from the pointer position and the BOF 
    rewind(f); // with this info, move back to BOF 

    if (size < 0){ // another safety check
        fclose(f);
        return NULL;
    }

    char *buffer = malloc((size_t)size + 1); // allocate memory for the file and null terminator
    if (!buffer){
        fclose(f);
        return NULL;
    }

    size_t read = fread(buffer, 1, (size_t)size, f); // read size bytes, one at a time, from f into buffer
    fclose(f); // close the file because we're done with it 

    if (read != (size_t)size){ // ensure that f and buffer are the same size
        free(buffer);
        return NULL; 
    }

    buffer[size] = '\0'; // add a null terminator so we can use the file like a c string

    return buffer;
}

void skip(Parser *p){
      // this function advances the pointer throughout the file for white space, tabs, comments, etc.
    while (*p->cur){ // while the value of the pointer is not the null terminator
        if (*p->cur == ' ' || *p->cur == '\t' || *p->cur == '\r'){
            p->cur++; // move the pointer
        }
        else if (*p->cur == '\n'){
            p->cur++;
            p->line++;
        }
        else if (*p->cur == 'c' && p->cur[1] != 'n'){ // comment line 
            while (*p->cur && *p->cur != '\n'){
                p->cur++;
            }
        }
        else break;
    }
}

int parse_literal(Parser *p){
    // this function parses a literal value from a DIMACS file 
    skip(p);

    int sign = 1;

    if (*p->cur == '-'){ // if the next literal is negative
        sign = -1;
        p->cur++;
    }

    int value = 0;
    while (*p->cur >= '0' && *p->cur <= '9'){ // c method for parsing an int from a str
        value = value * 10 + (*p->cur - '0'); 
        p->cur++;
    }

    return sign * value;
}

int parse_header(Parser *p){
    // this function parses the header to get the number of clauses and variables
    skip(p);

    if (*p->cur != 'p'){
        fprintf(stderr, "Error: Expected 'p' for header line");
        return 1;
    }

    p->cur++;
    skip(p);

    if (p->cur[0] != 'c' || p->cur[1] != 'n' || p->cur[2] != 'f'){
        fprintf(stderr, "Error: Malformed header line, missing 'cnf' at line %d\n", p->line);
        return 1;
    }

    p->cur+=3;
    skip(p);

    p->nvars = parse_literal(p);
    skip(p);
    p->nclauses = parse_literal(p);

    return 0;
}
    
Clause parse_clause(Parser *p){
    // parses a clause and returns it as a Clause struct
    Clause c;
    c.lits = NULL;
    c.size = 0;

    int new_lit = 0;
    while (1){
        new_lit = parse_literal(p);
        if (new_lit == 0) break; // exit the loop if the next literal is a 0, denoting the end of a line

        int *tmp = realloc(c.lits, (c.size + 1)*sizeof(int)); // make lits one integer larger 
        if (!tmp){
            free(c.lits);
            fprintf(stderr, "Failed to allocate memory at line %d\n", p->line);
            exit(1); // exits with error code noe
        }

        c.lits = tmp; // set the memory address of lits to that of tmp
        c.lits[c.size] = new_lit; 
        c.size++;
    }
    return c;

}

CNF parse_cnf(Parser *p){
    CNF cnf = {0};

    if (parse_header(p) != 0){ // if the header parse was not successful, exit
        fprintf(stderr,"Error: Failed to parse header.\n");
        exit(1);
    }
    cnf.nvars = p->nvars; 
    cnf.nclauses = p->nclauses;

    cnf.clauses = malloc(cnf.nclauses * sizeof(Clause)); // allocate memory for the correct number of clauses

    if (!cnf.clauses){
        fprintf(stderr, "Error: Failed to allocate memory for clauses.\n");
        exit(1);
    }

    for (int i = 0; i < cnf.nclauses; i++){
        cnf.clauses[i] = parse_clause(p); // parse clauses into clause list 

        // literal validation, make sure all literals are in the specified range 
        for (int j = 0; j < cnf.clauses[i].size; j++){
            int lit = abs(cnf.clauses[i].lits[j]);
            if (lit < 1 || lit > cnf.nvars){
                fprintf(stderr, "Error: Invalid literal value\n");
                exit(1);
            }
        }
    }
    return cnf;
}

void free_cnf(CNF *cnf){
    if (cnf == NULL || cnf->clauses == NULL) return; // exit if the CNF is empty

    for (int i = 0; i < cnf->nclauses; i++){
        free(cnf->clauses[i].lits); // free all of the lits in an individual clause
    }

    free(cnf->clauses); // free memory dedicated to the clauses struct

    cnf->clauses = NULL;
    cnf->nvars = 0; 
    cnf->nclauses = 0;

    return;
}

int main(){
    char *buffer = load_file("exdimacs.cnf"); // read the file
    if (!buffer){
        fprintf(stderr, "Failed to load file.");
        return 1;
    }

    Parser parse; // initialize the parser 
    parse.cur = buffer;
    parse.line = 1;
    parse.nvars = 0; 
    parse.nclauses = 0; 

    CNF cnf = parse_cnf(&parse); // read the cnf

    printf("Parsed CNF successfully.\n"); //what is fprintf vs printf
    printf("Number of clauses: %d.\n", cnf.nclauses);
    printf("Number of variables: %d.\n", cnf.nvars);

    free_cnf(&cnf); // free memory allocated to cnf and buffer
    free(buffer);

    return 0;
}


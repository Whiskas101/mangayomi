// To expose sudachi functionality to flutter
use flutter_rust_bridge::frb;

use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::Path;
use std::path::PathBuf;
use std::{env, usize};

use sudachi::analysis::mlist::MorphemeList;
use sudachi::analysis::stateless_tokenizer::StatelessTokenizer;
use sudachi::analysis::Mode;
use sudachi::analysis::Tokenize;
use sudachi::config::ConfigBuilder;
use sudachi::dic::dictionary::JapaneseDictionary;
use sudachi::error::SudachiError;

use serde::Serialize;

// for J->E meaning lookups
use jmdict::{self, GlossLanguage};

// for storing the loading sudachi dict in memory
use once_cell::sync::OnceCell;
use std::sync::Mutex;

static GLOBAL_DICT: OnceCell<Mutex<JapaneseDictionary>> = OnceCell::new();

// To embed this as part of the binary
const SYSTEM_DIC_BYTES: &[u8] = include_bytes!("resources\\system_full.dic");
const CONFIG_JSON: &str = include_str!("resources\\sudachi.json");

#[frb]
#[derive(Debug)]
pub enum TokenizerError {
    ConfigError,
    DictLoadError,
    TokenizeError,
}

#[frb]
#[derive(Debug, Serialize)]
pub struct TokenData {
    pub surface: String,
    pub dictionary_form: String,
    pub normalized_form: String,
    pub reading_form: String,
    pub pos: Vec<String>,
    // pub inflection_type: String,
    // pub inflection_form: String,
    pub is_oov: bool,
}

#[frb]
#[derive(Debug, Serialize)]
pub struct ResultToken {
    pub surface: String,
    pub dictionary_form: String,
    pub normalized_form: String,
    pub reading_form: String,
    pub pos: Vec<String>,
    // pub inflection_type: String,
    // pub inflection_form: String,
    pub is_oov: bool,

    // Additional information
    pub glosses: Vec<String>,
    pub match_found: bool,
    // pub dict_readings: Vec<String>,
}

fn log_cwd_to_file(log: String) {
    let path = get_log_path();

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .unwrap_or_else(|_| panic!("Failed to open log file"));

    match env::current_dir() {
        Ok(cwd) => {
            writeln!(file, "{:?} || {}", cwd, log).ok();
        }
        Err(e) => {
            writeln!(file, "Failed to get current directory: {:?}", e).ok();
        }
    }
}

fn get_log_path() -> PathBuf {
    // Using a platform-specific writable location
    if cfg!(target_os = "android") {
        PathBuf::from("/data/data/com.your.package.name/files/rust_log.txt")
    } else {
        // Desktop/dev fallback
        PathBuf::from("rust_log.txt")
    }
}

#[frb]
pub fn get_rust_cwd() -> String {
    env::current_dir()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|e| format!("Error: {:?}", e))
}

fn extract_tokens(
    morphs: MorphemeList<&JapaneseDictionary>,
    dict: &JapaneseDictionary,
) -> Vec<TokenData> {
    morphs
        .iter()
        .map(|m| {
            let pos_id = m.get_word_info().pos_id();
            let pos = dict
                .grammar()
                .pos_list
                .get(pos_id as usize)
                .map(|p| p.iter().map(|s| s.to_string()).collect())
                .unwrap_or_else(|| vec!["*".to_string(); 4]);

            TokenData {
                surface: m.surface().to_string(),
                dictionary_form: m.dictionary_form().to_string(),
                normalized_form: m.normalized_form().to_string(),
                reading_form: m.reading_form().to_string(),
                pos: pos,
                // inflection_type: m.inflection_type().to_string(),
                // inflection_form: m.inflection_form().to_string(),
                is_oov: m.is_oov(),
            }
        })
        .collect()
}

#[frb]
pub fn init_tokenizer(config_path: String) -> Result<(), TokenizerError> {
    if GLOBAL_DICT.get().is_some() {
        return Ok(());
    }
    let path = Path::new(&config_path);
    log_cwd_to_file(path.to_string_lossy().into());

    let config_builder = ConfigBuilder::from_file(path).map_err(|_| TokenizerError::ConfigError)?;
    let config = config_builder.build();
    let dict = JapaneseDictionary::from_cfg(&config).map_err(|_| TokenizerError::DictLoadError)?;

    GLOBAL_DICT
        .set(Mutex::new(dict))
        .map_err(|_| TokenizerError::DictLoadError)?;
    Ok(())
}

pub fn tokenize_text(input: String) -> Result<Vec<TokenData>, TokenizerError> {
    // Currently hardcoded but because i dont think this is something i'll ever need to change
    // log_cwd_to_file();
    // init_tokenizer("resources\\sudachi.json".into());
    let dict = GLOBAL_DICT
        .get()
        .ok_or(TokenizerError::DictLoadError)?
        .lock()
        .map_err(|_| TokenizerError::DictLoadError)?;
    let tokenizer = StatelessTokenizer::new(&*dict);
    let morpheme_list = tokenizer
        .tokenize(&input, Mode::B, false)
        .map_err(|_| TokenizerError::TokenizeError)?;

    Ok(extract_tokens(morpheme_list, &*dict))
}

fn lookup_glosses(lemma: &str) -> Vec<String> {
    // performs a linear search
    // TODO: Use some Tree or other data structure to speed this up

    let mut results: Vec<String> = Vec::new();

    for entry in jmdict::entries() {
        let matched = entry.kanji_elements().any(|k| k.text == lemma)
            || entry.reading_elements().any(|r| r.text == lemma);

        if matched {
            let glosses: Vec<String> = entry
                .senses()
                .flat_map(|s| s.glosses())
                .filter(|g| g.language == GlossLanguage::English)
                .map(|g| g.text.to_string())
                .collect();
            results.extend(glosses);
        }
    }
    results
}

#[frb]
pub fn lookup_sentence(input: String) -> Vec<ResultToken> {
    // just returns the fattest json that can be made out of all information
    // extracted out of this set of tokens

    // TODO: Optimize this slow ahh search
    // currently doing a raw linear search for every query
    // prioritising working version before fast version fr
    //

    let tokens = tokenize_text(input).unwrap();

    let result: Vec<ResultToken> = tokens
        .into_iter()
        .map(|t| {
            let glosses = lookup_glosses(&t.dictionary_form);
            ResultToken {
                surface: t.surface,
                dictionary_form: t.dictionary_form,
                normalized_form: t.normalized_form,
                reading_form: t.reading_form,
                pos: t.pos,
                is_oov: t.is_oov,
                glosses: glosses.clone(),
                match_found: !glosses.is_empty(),
            }
        })
        .collect();

    result
}

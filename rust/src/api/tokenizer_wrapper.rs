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

use serde::Serialize;

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

fn log_cwd_to_file() {
    let path = get_log_path();

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .unwrap_or_else(|_| panic!("Failed to open log file"));

    match env::current_dir() {
        Ok(cwd) => {
            writeln!(file, "Current working directory: {:?}", cwd).ok();
        }
        Err(e) => {
            writeln!(file, "Failed to get current directory: {:?}", e).ok();
        }
    }
}

fn get_log_path() -> PathBuf {
    // Use a platform-specific writable location
    if cfg!(target_os = "android") {
        // On Android, write to app's internal files dir — assuming you've set this up
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
pub fn tokenize_text(input: String) -> Result<Vec<TokenData>, TokenizerError> {
    // Currently hardcoded but because i dont think this is something i'll ever need to change
    log_cwd_to_file();
    let config_builder = ConfigBuilder::from_file(Path::new("rust/src/resources/sudachi.json"))
        .map_err(|_| TokenizerError::ConfigError)?;
    let config = config_builder.build();
    let dict = JapaneseDictionary::from_cfg(&config).map_err(|_| TokenizerError::DictLoadError)?;
    let tokenizer = StatelessTokenizer::new(&dict);
    let morpheme_list = tokenizer
        .tokenize(&input, Mode::B, true)
        .map_err(|_| TokenizerError::TokenizeError)?;

    Ok(extract_tokens(morpheme_list, &dict))
}

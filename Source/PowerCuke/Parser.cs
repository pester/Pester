using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using gherkin;
using gherkin.lexer;
using java.lang;
using java.util;
using PoshCode.PowerCuke.ObjectModel;

namespace PoshCode.PowerCuke
{
    public class Parser : Listener
    {
        private enum ScenarioType
        {
            Unknown,
            Background,
            Scenario,
            ScenarioOutline,
        }


        private readonly I18n language;
        private readonly List<string> featureTags = new List<string>();
        private readonly List<string> scenarioTags = new List<string>();
        
        private Feature _feature;
        private Scenario _scenario;
        private Step _step;
        private Example _example;

        private ScenarioType _type = ScenarioType.Unknown;

        #region Listener Members

        public void comment(string comment, Integer line)
        {
            // TODO - implement search for metatags here in the future
        }

        public void tag(string tag, Integer line)
        {
            // loose the @
            tag = tag.Substring(1);
            if (this._feature == null)
            {
                this.featureTags.Add(tag);
            }
            else
            {
                this.scenarioTags.Add(tag);
            }
        }

        public void feature(string keyword, string name, string description, Integer line)
        {
            this._type = ScenarioType.Unknown;
            this._feature = new Feature
            {
                Name = name,
                Description = description,
                Tags = new List<string>(this.featureTags)
            };
            this.featureTags.Clear();
        }

        public void background(string keyword, string name, string description, Integer line)
        {
            this._type = ScenarioType.Background;
            this._scenario = new Scenario(_feature)
            {
                Name = name,
                Description = description
            };
        }

        public void scenario(string keyword, string name, string description, Integer line)
        {
            this.CleanUpFinishedElements();
            this._type = ScenarioType.Scenario;

            this._scenario = new Scenario(_feature)
            {
                Name = name,
                Description = description,
                Tags = new List<string>(this.scenarioTags)
            };
            this.scenarioTags.Clear();
        }

        public void scenarioOutline(string keyword, string name, string description, Integer line)
        {
            this.CleanUpFinishedElements();

            this._type = ScenarioType.ScenarioOutline;
            this._scenario = new ScenarioOutline(_feature)
            {
                Name = name,
                Description = description,
                Tags = new List<string>(this.scenarioTags)
            };
            this.scenarioTags.Clear();
        }

        public void examples(string keyword, string name, string description, Integer line)
        {
            if (this._example != null)
            {
                ((ScenarioOutline)this._scenario).Examples.Add(this._example);
            }
            this._example = new Example()
            {
                Name = name,
                Description = description
            };
        }

        public void step(string keyword, string name, Integer line)
        {
            if (this._step != null)
            {
                _scenario.Steps.Add(_step);
            }

            this._step = new Step
            {
                Name = name,
                Keyword = TryParseKeyword(keyword),
                NativeKeyword = keyword
            };
        }

        public void row(List cells, Integer line)
        {
            if (this._example != null)
            {
                this._example.Add(cells);
            }
            else
            {
                this._step.TableArgument.Add(cells);
            }
        }

        public void docString(string contentType, string content, Integer line)
        {
            this._step.DocStringArgument = content;
        }

        public void eof()
        {
            this.CleanUpFinishedElements();
        }

        #endregion

        public Feature GetFeature()
        {
            return this._feature;
        }


        public Keyword? TryParseKeyword(string keyword)
        {
            if (this.language.keywords("and").contains(keyword)) return Keyword.And;

            if (this.language.keywords("given").contains(keyword)) return Keyword.Given;

            if (this.language.keywords("when").contains(keyword)) return Keyword.When;

            if (this.language.keywords("then").contains(keyword)) return Keyword.Then;

            if (this.language.keywords("but").contains(keyword)) return Keyword.But;

            if (!keyword.EndsWith(" ")) return this.TryParseKeyword(keyword + " ");

            return null;
        }

        /// <summary>
        /// This method is called when we're starting a new element to finish off and store whatever has been parsed.
        /// </summary>
        private void CleanUpFinishedElements()
        {
            if (this._example != null)
            {
                var outline = this._scenario as ScenarioOutline;
                if (outline != null)
                {
                    outline.Examples.Add(this._example);
                }
                this._example = null;
            }


            if (this._step != null)
            {
                this._scenario.Steps.Add(this._step);
                this._step = null;
            }

            if (this._scenario != null)
            {
                this._scenario.Feature = this._feature;
                this._scenario.Tags.AddRange(this._feature.Tags);
                if (this._type == ScenarioType.Background)
                {
                    this._feature.Background = this._scenario;
                }
                else
                {
                    this._feature.Scenarios.Add(this._scenario);
                }
            }

            this._scenario = null;
            this._type = ScenarioType.Unknown;
        }


        public static I18n GetLanguage(string language)
        {
            var currentCulture = (language != null)
                ? CultureInfo.GetCultureInfo(language)
                : CultureInfo.CurrentUICulture;

            return new I18n(currentCulture.TwoLetterISOLanguageName);
        }

        public static Feature Parse(string content, string language = null)
        {

            I18n lang = GetLanguage(language);
            var parser = new Parser(lang);

            Lexer lexer = lang.lexer(parser);
            lexer.scan(content);

            return parser.GetFeature();
        }
        public Parser(I18n language)
        {
            this.language = language;
        }

        public Parser(string language)
        {
            this.language = GetLanguage(language);
        }
    }
}

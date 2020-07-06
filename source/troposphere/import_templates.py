#!/usr/bin/env python3

from troposphere.template_generator import TemplateGenerator
import json
import yaml
from cfn_tools import dump_yaml, load_yaml
from cfn_flip import flip

with open("../templates/Analytics.template") as f:
    #json_template = json.load(f)
    template_dict = load_yaml(f)
    print(template_dict)
    template_yaml = dump_yaml(template_dict)
    print(template_yaml)
    template_dict = yaml.load(template_yaml, Loader=yaml.Loader)
    print(template_dict)
    template_json = flip(template_yaml)
    #analytics_template = TemplateGenerator(template_json)
    analytics_template = TemplateGenerator(template_dict)
    #template.to_json()
    #print(analytics_template)
    s = analytics_template.to_yaml()
    

using Models.DisplayBoard;
using Newtonsoft.Json;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class DisplayBoardService : IDisplayBoardService
    {
        private readonly ConfigSettingService configSettingService;
        private const string GROUPNAME = "DisplayBoardFileGenerator";
        public DisplayBoardService(ConfigSettingService _configSettingService)
        {
            configSettingService = _configSettingService;
        }
        public void CreateTemplate(Template template)
        {
            if (TemplateExists(template.FileName, template.FilePath,template.FileType))
            {
                throw new InvalidOperationException("A template with the same file name already exists at the specified path.");
            }
            Guid templateId = Guid.NewGuid();
            template.Id = templateId;
            Models.Post.ConfigSetting config = new Models.Post.ConfigSetting
            {
                GroupName = GROUPNAME,
                ContentName = $"Template_{templateId}",
                ContentValue = Newtonsoft.Json.JsonConvert.SerializeObject(template)
            };
            configSettingService.CreateConfigSetting(config);
        }

        public IEnumerable<Template> GetAllTemplates()
        {
            List<Template> templates = new List<Template>();
            var templateSettings = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName.StartsWith("Template_"));
            foreach(var template in templateSettings)
            {
                templates.Add(Newtonsoft.Json.JsonConvert.DeserializeObject<Template>(template.ContentValue));
            }
            return templates;
        }
        private string NormalizePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return string.Empty;

            return path.Trim().TrimEnd('/').ToLowerInvariant();
        }
        private bool TemplateExists(string fileName, string filePath, string fileType)
        {
            string normalizedPath = NormalizePath(filePath);

            return GetAllTemplates().Any(t =>
                t.FileName.Equals(fileName, StringComparison.OrdinalIgnoreCase) &&
                NormalizePath(t.FilePath) == normalizedPath &&
                t.FileType.Equals(fileType, StringComparison.OrdinalIgnoreCase));
        }

        public void DeleteTemplate(string id)
        {
            var templateSetting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == $"Template_{id}").FirstOrDefault();
            if (templateSetting == null)
            {
                throw new ArgumentException("Cannot find template to delete.");
            }
            configSettingService.DeleteConfigSetting(templateSetting.Id);
        }

        public Template GetTemplate(string id)
        {
            var templates = GetAllTemplates();
            return templates.Where(e => e.Id == Guid.Parse(id)).FirstOrDefault();
        }

        public void UpdateTemplate(Template template)
        {
            var templateSetting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == $"Template_{template.Id}").FirstOrDefault();
            if (templateSetting == null)
            {
                throw new ArgumentException("Cannot find subscription to update.");
            }
            templateSetting.ContentValue = JsonConvert.SerializeObject(template);
            configSettingService.UpdateConfigSetting(templateSetting);
        }
    }
}

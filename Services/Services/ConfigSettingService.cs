using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class ConfigSettingService : IConfigSettingService
    {
        private readonly IConfigSettingRepository _configSettingsRepository;
        public ConfigSettingService(IConfigSettingRepository configSettingsRepository)
        {
            _configSettingsRepository = configSettingsRepository;
        }
        public void CreateConfigSetting(Models.Post.ConfigSetting configSetting)
        {
            var configSettingsMatchedWithContentNameOfSameGroup = _configSettingsRepository.GetByGroupName(configSetting.GroupName).ToList().Where(e=>e.ContentName==configSetting.ContentName);
            if (configSettingsMatchedWithContentNameOfSameGroup.Any())
            {
                throw new Exceptions.CannotCreateMultipleContentsWithSameNameInSameGroup(configSetting.ContentName, configSetting.GroupName);
            }
            _configSettingsRepository.Add(configSetting);
        }

        public void DeleteConfigSetting(int id)
        {
            _configSettingsRepository.Delete(id);
        }

        public IEnumerable<Models.ConfigSetting> GetAllConfigSettings()
        {
            return _configSettingsRepository.GetAll();
        }

        public Models.ConfigSetting GetConfigSettingById(int id)
        {
            return _configSettingsRepository.GetById(id);
        }

        public IEnumerable<Models.ConfigSetting> GetConfigSettingsByGroupName(string groupName)
        {
            return _configSettingsRepository.GetByGroupName(groupName);
        }

        public void UpdateConfigSetting(Models.ConfigSetting configSetting)
        {
            _configSettingsRepository.Update(configSetting);
        }
    }
}

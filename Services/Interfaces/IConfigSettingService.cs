using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IConfigSettingService
    {
        IEnumerable<ConfigSetting> GetAllConfigSettings();
        IEnumerable<ConfigSetting> GetConfigSettingsByGroupName(string groupName);
        ConfigSetting GetConfigSettingById(int id);
        void CreateConfigSetting(Models.Post.ConfigSetting configSetting);
        void UpdateConfigSetting(ConfigSetting configSetting);
        void DeleteConfigSetting(int id);
    }
}

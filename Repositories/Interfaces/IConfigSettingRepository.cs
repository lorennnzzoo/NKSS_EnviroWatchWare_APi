using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface IConfigSettingRepository
    {
        IEnumerable<ConfigSetting> GetAll();
        ConfigSetting GetById(int id);
        void Add(Models.Post.ConfigSetting configSettings);
        void Update(ConfigSetting configSettings);
        void Delete(int id);
        IEnumerable<ConfigSetting> GetByGroupName(string groupName);
    }
}

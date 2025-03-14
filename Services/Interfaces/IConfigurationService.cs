using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Models;

namespace Services.Interfaces
{
    public interface IConfigurationService
    {
        Dictionary<string, object> GetConfiguration();
        IEnumerable<ConfigSetting> GetApiContracts();

        Dictionary<string, object> GetUploadConfig(int companyId,List<int> stationIds,List<int> channelIds);
    }
}

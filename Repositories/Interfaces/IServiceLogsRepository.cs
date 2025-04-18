using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface IServiceLogsRepository
    {
        IEnumerable<ServiceLogs> GetPast24HourLogsByType(string Type);
        IEnumerable<string> GetSoftwareTypes();

        IEnumerable<ServiceLogs> GetLastMinuteLogsByType(string Type);
    }
}

using Models;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class ServiceLogsService : IServiceLogsService
    {
        private readonly IServiceLogsRepository _serviceLogsRepository;
        public ServiceLogsService(IServiceLogsRepository serviceLogsRepository)
        {
            _serviceLogsRepository = serviceLogsRepository;
        }
        public IEnumerable<ServiceLogs> Get24HourLogsByType(string Type)
        {
            return _serviceLogsRepository.GetPast24HourLogsByType(Type);
        }

        public IEnumerable<ServiceLogs> GetLastMinuteLogsByType(string Type)
        {
            return _serviceLogsRepository.GetLastMinuteLogsByType(Type);
        }

        public IEnumerable<string> GetTypes()
        {
            return _serviceLogsRepository.GetSoftwareTypes();
        }
    }
}

using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;

namespace Services
{
    public class MonitoringTypeService : IMonitoringTypeService
    {
        private readonly IMonitoringTypeRepository _monitoringTypeRepository;
        public MonitoringTypeService(IMonitoringTypeRepository monitoringTypeRepository)
        {
            _monitoringTypeRepository = monitoringTypeRepository;
        }
        public void CreateMonitoringType(Models.Post.MonitoringType monitoringType)
        {
            _monitoringTypeRepository.Add(monitoringType);
        }

        public void DeleteMonitoringType(int id)
        {
            _monitoringTypeRepository.Delete(id);
        }

        public IEnumerable<Models.MonitoringType> GetAllMonitoringTypes()
        {
            return _monitoringTypeRepository.GetAll();
        }

        public Models.MonitoringType GetMonitoringTypeById(int id)
        {
            return _monitoringTypeRepository.GetById(id);
        }

        public void UpdateMonitoringType(Models.MonitoringType monitoringType)
        {
            _monitoringTypeRepository.Update(monitoringType);
        }
    }
}

using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;

namespace Services
{
    public class CompanyService : ICompanyService
    {
        private readonly ICompanyRepository _companyRepository;

        // Constructor for dependency injection
        public CompanyService(ICompanyRepository companyRepository)
        {
            _companyRepository = companyRepository;
        }

        public IEnumerable<Company> GetAllCompanies()
        {
            return _companyRepository.GetAll();
        }

        public Company GetCompanyById(int id)
        {
            return _companyRepository.GetById(id);
        }

        public void CreateCompany(Post.Company company)
        {
            IEnumerable<Company> companies=_companyRepository.GetAll().Where(e=>e.Active==true);
            if (companies .Count()>0)
            {
                throw new Exceptions.CompanyExceptions();
            }
            _companyRepository.Add(company);
        }

        public void UpdateCompany(Models.Put.Company company)
        {
            _companyRepository.Update(company);
        }

        public void DeleteCompany(int id)
        {
            _companyRepository.Delete(id);
        }
    }

}

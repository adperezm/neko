#include <adios2.h>
#include <memory>
#include <string>
#include <iostream>
#include <ctime>
#include <vector>

// Forward declarations
class ContinuousArray;
class Variable;

// ===============================================================================================
// Class that encapsulates a Continuous array
// ===============================================================================================

class ContinuousArray
{
public:
    ContinuousArray(adios2::IO &io,
                    const std::string &name,
                    unsigned int global_size,
                    unsigned int start,
                    unsigned int count);
    ~ContinuousArray() = default;

    const std::string &get_name() const { return name_; }
    const adios2::Variable<double> &get_array() const { return f2py_array_; }
    unsigned int get_start() const { return start_; }
    unsigned int get_count() const { return count_; }

private:
    std::string name_;
    unsigned int global_size_;
    unsigned int start_;
    unsigned int count_;
    adios2::Variable<double> f2py_array_;
};

ContinuousArray::ContinuousArray(adios2::IO &io,
                                 const std::string &name,
                                 unsigned int global_size,
                                 unsigned int start,
                                 unsigned int count)
    : name_(name), global_size_(global_size), start_(start), count_(count)
{
    f2py_array_ = io.DefineVariable<double>(name_, {global_size_}, {start_}, {count_});
}

// ===============================================================================================
// Class that encapsulates a variable
// ===============================================================================================

class Variable
{
public:
    Variable(adios2::IO &io, const std::string &name);
    ~Variable() = default;

    const std::string &get_name() const { return name_; }
    const adios2::Variable<int> &get_variable() const { return variable_; }

private:
    std::string name_;
    adios2::Variable<int> variable_;
};

Variable::Variable(adios2::IO &io, const std::string &name)
    : name_(name)
{
    variable_ = io.DefineVariable<int>(name_);
}

// ===============================================================================================
// Class that encapsulates a stream
// ===============================================================================================

class Stream
{
public:
    Stream(MPI_Comm comm,
           const std::string &io_name = "globalArray",
           int id = 0, 
           int timeout_seconds = 300);
    ~Stream();

    void add_array(const std::string &name,
                   unsigned int global_size,
                   unsigned int start,
                   unsigned int count);

    void add_variable(const std::string &name);

    void write_array(const double *field, unsigned int array_id);
    void write_variable(const int *variable, unsigned int variable_id);

    void read_array(double *field, unsigned int array_id);
    void read_variable(int *variable, unsigned int variable_id);

private:
    MPI_Comm comm_;
    int rank_ = 0;
    int size_ = 0;
    int id_ = 0;
    int timeout_seconds_ = 300;
    std::string io_name_;
    adios2::ADIOS adios_;
    adios2::IO io_;
    adios2::Engine writer_;
    adios2::Engine reader_;
    std::vector<ContinuousArray> arrays_;
    std::vector<Variable> variables_;
};

// When initializing this, make sure the communicator has already been converted from Fortran to C
Stream::Stream(MPI_Comm comm, const std::string &io_name, int id, int timeout_seconds)
    : comm_(comm), id_(id), io_name_(io_name), adios_(comm_), timeout_seconds_(timeout_seconds)
{
    MPI_Comm_rank(comm_, &rank_);
    MPI_Comm_size(comm_, &size_);

    io_ = adios_.DeclareIO(io_name_ + "_io");
    io_.SetEngine("SST");
    io_.SetParameters({{"OpenTimeoutSecs", std::to_string(timeout_seconds_)}});

    const std::string writer_name = io_name_ + "_f2py";
    const std::string reader_name = io_name_ + "_py2f";

    if (rank_ == 0)
    {
        std::cout << "Opening " << writer_name << ".sst" << std::endl;
        std::cout << "Opening " << reader_name << ".sst" << std::endl;
    }

    writer_ = io_.Open(writer_name, adios2::Mode::Write);
    reader_ = io_.Open(reader_name, adios2::Mode::Read);
}

Stream::~Stream()
{
    if (writer_)
    {
        if (rank_ == 0)
        {
            std::cout << "Closing writer" << std::endl;
        }
        writer_.Close();
    }

    if (reader_)
    {
        if (rank_ == 0)
        {
            std::cout << "Closing reader" << std::endl;
        }
        reader_.Close();
    }
}

void Stream::add_array(const std::string &name,
                       unsigned int global_size,
                       unsigned int start,
                       unsigned int count)
{
    arrays_.emplace_back(io_, name, global_size, start, count);
}

void Stream::add_variable(const std::string &name)
{
    variables_.emplace_back(io_, name);
}

void Stream::write_array(const double *field, unsigned int array_id)
{
    // Fortran IDs are 1-based
    if (array_id == 0 || array_id > arrays_.size())
    {
        std::cerr << "Array ID " << array_id << " is out of bounds." << std::endl;
        return;
    }

    writer_.BeginStep();
    writer_.Put(arrays_[array_id - 1].get_array(), field);
    writer_.EndStep();
}

void Stream::write_variable(const int *variable, unsigned int variable_id)
{
    // Fortran IDs are 1-based
    if (variable_id == 0 || variable_id > variables_.size())
    {
        std::cerr << "Variable ID " << variable_id << " is out of bounds." << std::endl;
        return;
    }

    writer_.BeginStep();
    writer_.Put(variables_[variable_id - 1].get_variable(), *variable);
    writer_.EndStep();
}

void Stream::read_array(double *field, unsigned int array_id)
{
    if (array_id == 0 || array_id > arrays_.size())
    {
        std::cerr << "Array ID " << array_id << " is out of bounds." << std::endl;
        return;
    }

    reader_.BeginStep();

    adios2::Variable<double> py2f_array =
        io_.InquireVariable<double>(arrays_[array_id - 1].get_name());

    if (!py2f_array)
    {
        std::cerr << "Could not inquire array " << arrays_[array_id - 1].get_name()
                  << std::endl;
        reader_.EndStep();
        return;
    }

    py2f_array.SetSelection({{arrays_[array_id - 1].get_start()},
                             {arrays_[array_id - 1].get_count()}});

    reader_.Get(py2f_array, field);
    reader_.EndStep();
}

void Stream::read_variable(int *variable, unsigned int variable_id)
{
    if (variable_id == 0 || variable_id > variables_.size())
    {
        std::cerr << "Variable ID " << variable_id << " is out of bounds." << std::endl;
        return;
    }

    reader_.BeginStep();

    adios2::Variable<int> py2f_variable =
        io_.InquireVariable<int>(variables_[variable_id - 1].get_name());

    if (!py2f_variable)
    {
        std::cerr << "Could not inquire variable " << variables_[variable_id - 1].get_name()
                  << std::endl;
        reader_.EndStep();
        return;
    }

    reader_.Get(py2f_variable, variable);
    reader_.EndStep();
}

// ===============================================================================================
// C functions for fortran to call
// ===============================================================================================
std::vector<std::unique_ptr<Stream>> streams;

extern "C" void adios2_initialize_(
    const int *comm,
    const char *io_name,
    const int id,
    const int timeout_seconds)
{
    MPI_Comm c_comm = MPI_Comm_f2c(*comm);
    std::string io_name_str(io_name);
    streams.emplace_back(std::make_unique<Stream>(c_comm, io_name_str, id, timeout_seconds));
}

extern "C" void adios2_write_variable_(
    const int stream_id,
    const char *var_name,
    const int *variable)
{

    if (stream_id == 0 || stream_id > streams.size())
    {
        std::cerr << "Stream ID " << stream_id << " is out of bounds." << std::endl;
        return;
    }

    std::string var_name_str(var_name);

    // Search for the variable by name and write it.
    int it = std::find_if(streams[stream_id - 1]->variables_.begin(), streams[stream_id - 1]->variables_.end(),
                       [&var_name_str](const Variable &var) { return var.get_name() == var_name_str; });

    streams[stream_id - 1]->write_variable(variable, it);    
}

extern "C" void adios2_stream_(
    const double *field
){
    (void) field;
}

extern "C" void adios2_recieve_(
    double *field
){
    (void) field;
}
